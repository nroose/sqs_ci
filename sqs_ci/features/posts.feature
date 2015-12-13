Feature: Check the posts feature
  Background: Pause for a while so that the status can be tested
    Given I pause for 30 seconds

  Scenario: I want to see the empty features list
    Given I go to the posts page
    Then I should see "Listing Posts"

  Scenario: I want to create a post
    Given I go to the posts page
    And I click "New Post"
    And I set the "Name" to "First Post"
    And I set the "Body" to "This is the body of the first post."
    And I click "Back"
    Then I should see "Post was successfully created"
    And I should see "Name: First Post"
    And I should see "Body: This is the body of the first post"
