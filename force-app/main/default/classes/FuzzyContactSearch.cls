/**
 * @description Classe utilitaire pour effectuer une recherche "fuzzy" (approximative) sur les contacts.
 * - Pré-filtrage SOSL
 * - Classement par distance de Levenshtein
 * - Normalisation (diacritiques, ponctuation légère) avant scoring
 * - Méthode @AuraEnabled pour LWC/Aura et @InvocableMethod pour Flow
 */
public with sharing class FuzzyContactSearch {

    private static final Integer RESULT_LIMIT    = 5;
    private static final Integer CANDIDATE_LIMIT = 50;

    //------------------------------------------------------------------------------------
    // TYPES INVOCABLES (Flow)
    //------------------------------------------------------------------------------------
    public class InvocableRequest {
        @InvocableVariable
        public String searchFullName;
    }

    public class InvocableResult {
        @InvocableVariable
        public List<Contact> foundContacts;
    }

    //------------------------------------------------------------------------------------
    // MÉTHODE INVOCABLE (Flow)
    //------------------------------------------------------------------------------------
    @InvocableMethod
    public static List<InvocableResult> searchFromFlow(List<InvocableRequest> requests) {
        List<InvocableResult> finalResults = new List<InvocableResult>();

        if (requests == null || requests.isEmpty() || String.isBlank(requests[0].searchFullName)) {
            InvocableResult empty = new InvocableResult();
            empty.foundContacts = new List<Contact>();
            finalResults.add(empty);
            return finalResults;
        }

        String searchName = requests[0].searchFullName;
        List<Contact> foundContacts = findMostProbableContacts(searchName);

        InvocableResult singleResult = new InvocableResult();
        singleResult.foundContacts = foundContacts;
        finalResults.add(singleResult);

        return finalResults;
    }

    //------------------------------------------------------------------------------------
    // LWC/AURA + LOGIQUE
    //------------------------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<Contact> findMostProbableContacts(String searchFullName) {
        if (String.isBlank(searchFullName)) {
            return new List<Contact>();
        }

        // AMÉLIORATION : Normaliser la chaîne de recherche en premier.
        // Cela supprime les civilités, les accents, etc., avant même la recherche SOSL.
        String normalizedSearchName = normalize(searchFullName);
        
        // 1) Pré-filtrage SOSL avec la chaîne déjà normalisée
        List<Contact> candidates = getCandidateContacts(normalizedSearchName);
        if (candidates.isEmpty()) {
            return new List<Contact>();
        }

        // 2) Scoring Levenshtein (la chaîne de recherche est déjà normalisée)
        List<FuzzySearchResult> scoredResults = new List<FuzzySearchResult>();

        for (Contact c : candidates) {
            String candidateName = (c != null && c.Name != null) ? normalize(c.Name) : '';
            Integer distance = calculateLevenshteinDistance(normalizedSearchName, candidateName);
            scoredResults.add(new FuzzySearchResult(c, distance));
        }

        scoredResults.sort();

        // 3) Top N
        List<Contact> finalResults = new List<Contact>();
        for (Integer i = 0; i < scoredResults.size() && i < RESULT_LIMIT; i++) {
            finalResults.add(scoredResults[i].contact);
        }
        return finalResults;
    }

    /**
     * @description Pré-filtrage SOSL. Utilise une stratégie de fallback pour les recherches complexes.
     * 1. Tente une recherche avec OR sur tous les termes.
     * 2. Si peu de résultats, tente une recherche plus large sur le premier terme seul.
     */
    private static List<Contact> getCandidateContacts(String name) {
        String sanitized = String.valueOf(name).trim();
        if (sanitized == '') return new List<Contact>();

        List<String> terms = sanitized.split('\\s+');
        List<String> cleanTerms = new List<String>();
        for (String t : terms) {
            if (!String.isBlank(t)) {
                cleanTerms.add(String.escapeSingleQuotes(t));
            }
        }
        if (cleanTerms.isEmpty()) return new List<Contact>();

        Map<Id, Contact> contactMap = new Map<Id, Contact>();
        
        // --- Première passe : Recherche avec OR sur tous les termes ---
        String orClause = String.join(cleanTerms, ' OR ');
        String orQuery =
            'FIND {'+ orClause + '} IN NAME FIELDS ' +
            'RETURNING Contact(Id, Name, FirstName, LastName, Email, Phone ORDER BY Name LIMIT ' + CANDIDATE_LIMIT + ')';

        Search.SearchResults orContainer = Search.find(orQuery);
        List<Search.SearchResult> orResults = (orContainer != null) ? orContainer.get('Contact') : null;

        if (orResults != null) {
            for (Search.SearchResult sr : orResults) {
                Contact c = (Contact) sr.getSObject();
                contactMap.put(c.Id, c);
            }
        }

        // --- Seconde passe (Fallback) : Si peu de résultats, recherche sur le premier terme ---
        // Cette étape est cruciale pour les cas avec plusieurs fautes (ex: "Laurin Beylai")
        if (contactMap.size() < 10 && cleanTerms.size() > 1) {
            String firstTermClause = cleanTerms[0];
            String firstTermQuery =
                'FIND {'+ firstTermClause + '} IN NAME FIELDS ' +
                'RETURNING Contact(Id, Name, FirstName, LastName, Email, Phone ORDER BY Name LIMIT ' + CANDIDATE_LIMIT + ')';
            
            Search.SearchResults firstTermContainer = Search.find(firstTermQuery);
            List<Search.SearchResult> firstTermResults = (firstTermContainer != null) ? firstTermContainer.get('Contact') : null;

            if (firstTermResults != null) {
                for (Search.SearchResult sr : firstTermResults) {
                    Contact c = (Contact) sr.getSObject();
                    contactMap.put(c.Id, c); // La map gère les doublons automatiquement
                }
            }
        }
        
        return contactMap.values();
    }

    /**
     * @description Distance de Levenshtein (itérative, en O(n*m)).
     */
    private static Integer calculateLevenshteinDistance(String s1, String s2) {
        if (s1 == null) s1 = '';
        if (s2 == null) s2 = '';

        Integer n = s1.length();
        Integer m = s2.length();
        if (n == 0) return m;
        if (m == 0) return n;

        Integer[] prev = new Integer[m + 1];
        Integer[] curr = new Integer[m + 1];

        for (Integer j = 0; j <= m; j++) prev[j] = j;

        for (Integer i = 1; i <= n; i++) {
            curr[0] = i;
            for (Integer j = 1; j <= m; j++) {
                Integer cost = (s1.charAt(i - 1) == s2.charAt(j - 1)) ? 0 : 1;
                Integer del  = prev[j] + 1;
                Integer ins  = curr[j - 1] + 1;
                Integer sub  = prev[j - 1] + cost;
                curr[j] = Math.min(Math.min(del, ins), sub);
            }
            Integer[] tmp = prev; prev = curr; curr = tmp;
        }
        return prev[m];
    }

    /**
     * @description Normalisation pour le scoring :
     * - minuscule + trim
     * - **supprime les civilités courantes (mr, mme, etc.)**
     * - apostrophes/tirets -> espace
     * - ligatures (œ/æ), diacritiques fréquents
     * - supprime ponctuation résiduelle
     * - espaces multiples comprimés
     */
    private static String normalize(String input) {
        if (String.isBlank(input)) return '';
        String s = input.toLowerCase().trim();
        
        // **AMÉLIORATION : Suppression des civilités en début de chaîne**
        // La regex cherche les civilités courantes, suivies d'un point optionnel et d'un espace.
        s = s.replaceAll('^(mrs|mr|ms|mme|mlle|dr|prof)\\.?\\s+', '');

        s = s.replaceAll('[-_\'’]', ' ');
        s = s.replaceAll('œ', 'oe');
        s = s.replaceAll('æ', 'ae');

        s = s.replaceAll('[àáâäãåā]', 'a');
        s = s.replaceAll('[çčć]', 'c');
        s = s.replaceAll('[ďđ]', 'd');
        s = s.replaceAll('[èéêëėęě]', 'e');
        s = s.replaceAll('[ìíîïĩįī]', 'i');
        s = s.replaceAll('[ñń]', 'n');
        s = s.replaceAll('[òóôöõőō]', 'o');
        s = s.replaceAll('[ùúûüůűū]', 'u');
        s = s.replaceAll('[ýÿỳŷ]', 'y');
        s = s.replaceAll('[šśșş]', 's');
        s = s.replaceAll('[žźż]', 'z');

        s = s.replaceAll('[^a-z0-9 ]', '');
        s = s.replaceAll('\\s+', ' ').trim();
        return s;
    }

    //------------------------------------------------------------------------------------
    // Objet de score triable
    //------------------------------------------------------------------------------------
    public class FuzzySearchResult implements Comparable {
        public Contact contact { get; private set; }
        public Integer score   { get; private set; }

        public FuzzySearchResult(Contact c, Integer s) {
            this.contact = c;
            this.score   = s;
        }

        public Integer compareTo(Object otherObj) {
            FuzzySearchResult other = (FuzzySearchResult) otherObj;
            if (this.score == other.score) return 0;
            return (this.score > other.score) ? 1 : -1; // ascendant (score plus bas = mieux)
        }
    }
}