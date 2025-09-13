/**
 * @description Classe de test pour FuzzyContactSearch.
 * Couvre les scénarios nominaux, les cas limites et la nouvelle logique de fallback.
 * Utilise Test.setFixedSearchResults pour des tests SOSL fiables.
 */
@isTest
private class FuzzyContactSearchTest {

    /**
     * @description Crée un jeu de données de test commun pour toutes les méthodes.
     */
    @testSetup
    static void makeData(){
        List<Contact> contactsToInsert = new List<Contact>{
            new Contact(FirstName='Lauren', LastName='Bailey', Email='lauren.bailey@test.com'),
            new Contact(FirstName='John', LastName='Smith', Email='john.smith@test.com'),
            new Contact(FirstName='Christopher', LastName='Jones', Email='chris.jones@test.com'),
            new Contact(FirstName='Sarah', LastName='Williams', Email='sarah.w@test.com'),
            new Contact(FirstName='David', LastName='Brown', Email='d.brown@test.com')
        };
        insert contactsToInsert;
    }

    /**
     * @description Teste le scénario principal avec une seule faute de frappe.
     * Doit trouver "Lauren Bailey" à partir de "Lauren Baily".
     */
    @isTest
    static void testSingleTypo_ShouldFindContact() {
        // CORRECTION : Simule la réponse SOSL
        Contact expectedContact = [SELECT Id FROM Contact WHERE FirstName = 'Lauren' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ expectedContact.Id });

        Test.startTest();
        List<Contact> results = FuzzyContactSearch.findMostProbableContacts('Lauren Baily');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Doit trouver un seul contact.');
        System.assertEquals('Lauren Bailey', results[0].Name, 'Le contact trouvé doit être Lauren Bailey.');
    }

    /**
     * @description Teste le scénario de fallback avec des erreurs sur les deux termes.
     * Doit trouver "Lauren Bailey" à partir de "Laurin Beylai".
     */
    @isTest
    static void testMultipleTypos_ShouldTriggerFallbackAndFindContact() {
        // CORRECTION : Simule la réponse SOSL
        Contact expectedContact = [SELECT Id FROM Contact WHERE FirstName = 'Lauren' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ expectedContact.Id });

        Test.startTest();
        List<Contact> results = FuzzyContactSearch.findMostProbableContacts('Laurin Beylai');
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Doit trouver au moins un contact grâce au fallback.');
        System.assertEquals('Lauren Bailey', results[0].Name, 'Le contact trouvé doit être Lauren Bailey.');
    }

    /**
     * @description Teste la normalisation qui supprime les civilités.
     * Doit trouver "John Smith" à partir de "Mr John Smith".
     */
    @isTest
    static void testWithSalutation_ShouldFindContact() {
        // CORRECTION : Simule la réponse SOSL
        Contact expectedContact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ expectedContact.Id });

        Test.startTest();
        List<Contact> results = FuzzyContactSearch.findMostProbableContacts('Mr John Smith');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Doit trouver un seul contact.');
        System.assertEquals('John Smith', results[0].Name, 'Le contact trouvé doit être John Smith.');
    }

    /**
     * @description Teste qu'une recherche pour un nom inexistant ne retourne rien.
     */
    @isTest
    static void testNonExistentContact_ShouldReturnEmpty() {
        // Pas besoin de simuler ici, on s'attend à un résultat vide.
        Test.setFixedSearchResults(new List<Id>{});
        
        Test.startTest();
        List<Contact> results = FuzzyContactSearch.findMostProbableContacts('Zaphod Beeblebrox');
        Test.stopTest();

        System.assertEquals(true, results.isEmpty(), 'Ne doit retourner aucun contact.');
    }

    /**
     * @description Teste que la méthode gère correctement une entrée vide.
     */
    @isTest
    static void testBlankInput_ShouldReturnEmpty() {
        Test.startTest();
        List<Contact> results = FuzzyContactSearch.findMostProbableContacts('');
        Test.stopTest();

        System.assertEquals(true, results.isEmpty(), 'Une recherche vide ne doit retourner aucun contact.');
    }
    
    /**
     * @description Teste la méthode invocable (utilisée par les Flows).
     */
    @isTest
    static void testInvocableMethod_ShouldWork() {
        // CORRECTION : Simule la réponse SOSL
        Contact expectedContact = [SELECT Id FROM Contact WHERE FirstName = 'Lauren' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ expectedContact.Id });

        FuzzyContactSearch.InvocableRequest request = new FuzzyContactSearch.InvocableRequest();
        request.searchFullName = 'Lauren Baily';
        
        List<FuzzyContactSearch.InvocableRequest> requests = new List<FuzzyContactSearch.InvocableRequest>{ request };
        
        Test.startTest();
        List<FuzzyContactSearch.InvocableResult> flowResults = FuzzyContactSearch.searchFromFlow(requests);
        Test.stopTest();
        
        System.assertEquals(1, flowResults.size(), 'La méthode invocable doit retourner un résultat.');
        System.assertEquals(1, flowResults[0].foundContacts.size(), 'Le résultat doit contenir un contact.');
        System.assertEquals('Lauren Bailey', flowResults[0].foundContacts[0].Name, 'Le contact trouvé via le flow doit être correct.');
    }
}