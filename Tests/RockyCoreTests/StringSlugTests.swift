import Testing
import Foundation
@testable import RockyCore

@Suite("String+Slug")
struct StringSlugTests {
    @Test("lowercases input")
    func lowercases() {
        #expect("ACME".slugified == "acme")
    }

    @Test("replaces spaces with hyphens")
    func spacesToHyphens() {
        #expect("Acme Corp".slugified == "acme-corp")
    }

    @Test("collapses multiple spaces into single hyphen")
    func multipleSpaces() {
        #expect("Acme  Corp".slugified == "acme-corp")
    }

    @Test("replaces underscores with hyphens")
    func underscoresToHyphens() {
        #expect("acme_corp".slugified == "acme-corp")
    }

    @Test("removes special characters")
    func specialCharacters() {
        #expect("My Project!".slugified == "my-project")
    }

    @Test("trims leading and trailing hyphens")
    func trimsHyphens() {
        #expect("--acme--".slugified == "acme")
    }

    @Test("collapses multiple consecutive special characters")
    func multipleSpecialChars() {
        #expect("a--b__c  d".slugified == "a-b-c-d")
    }

    @Test("already a slug passes through unchanged")
    func alreadySlug() {
        #expect("acme-corp".slugified == "acme-corp")
    }

    @Test("trims whitespace before slugifying")
    func trimWhitespace() {
        #expect("  My Project!  ".slugified == "my-project")
    }

    @Test("numbers are preserved")
    func numbersPreserved() {
        #expect("project-42".slugified == "project-42")
    }

    @Test("mixed case and special characters")
    func mixedInput() {
        #expect("My COOL_Project (v2)".slugified == "my-cool-project-v2")
    }
}
