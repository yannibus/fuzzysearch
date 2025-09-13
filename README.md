Fuzzy Contact Search for Salesforce
An Apex class that provides an intelligent, fault-tolerant "fuzzy" search for Contact records in Salesforce. This utility is designed to find the most relevant contacts even when the search query contains typos, variations in names, or salutations.

Features
Typo Tolerance: Correctly identifies contacts even with spelling mistakes in the first or last name (e.g., "Jhon Smoth" finds "John Smith").
Advanced Matching Algorithm: Uses a two-step process for optimal results:

A broad SOSL query to retrieve a list of potential candidates.

The Levenshtein distance algorithm to score and rank candidates based on similarity.

Smart Normalization: Ignores common salutations (Mr., Mrs., Mme, etc.) and normalizes characters (handling accents like é, à, etc.) before comparison.

Flow-Ready: Includes an @InvocableMethod, allowing you to easily integrate this fuzzy search capability directly into your Salesforce Flows without writing extra code.

High Performance: Optimized to respect Governor Limits and includes a robust, high-coverage test class for reliable deployments.

Usage
From Apex
You can call the method directly from your Apex code:

String searchName = 'Laurin Beylai';
List<Contact> probableContacts = FuzzyContactSearch.findMostProbableContacts(searchName);

for (Contact c : probableContacts) {
    System.debug('Found Contact: ' + c.Name);
}

From a Salesforce Flow
Drag an Action element onto your Flow canvas.

Search for the action named "Fuzzy Contact Search".

In the searchFullName input variable, provide the name you want to search for.

The action will return a list of the 5 most probable contacts in the foundContacts output variable.

Deployment
To deploy this component, retrieve the following files from this repository and deploy them to your Salesforce organization using Salesforce CLI or your preferred tool:

force-app/main/default/classes/FuzzyContactSearch.cls

force-app/main/default/classes/FuzzyContactSearch.cls-meta.xml

force-app/main/default/classes/FuzzyContactSearchTest.cls

force-app/main/default/classes/FuzzyContactSearchTest.cls-meta.xml
