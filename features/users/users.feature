Feature: Welcome Page
  In order to see the welcome page
  A user
  should be able to sign in or sign up

  Scenario: User is not signed up
    When I sign in with valid credentials
    Then I see an invalid login message
    And I should be signed out

  Scenario: User signs up successfully
    When I click on Register
    And I fill in the user details
    Then I should see the welcome message

  Scenario: User tries to sign up without filling in the details
    When I click on Register
    And I did not fill in the user details
    Then I should see the error cannot be blank

  Scenario: User didn't fills the first name while signing up
    When I click on Register
    And I fill in the user details without filling the first name
    Then I should not see the welcome message

  Scenario: User didn't fills the family name while signing up
    When I click on Register
    And I fill in the user details without filling the family name
    Then I should not see the welcome message

  Scenario: User enters the invalid email while signing up
    When I click on Register
    And I fill in the user details with invalid email
    Then I should see an error 'is invalid' on the page

  Scenario: User enters the short password
    When I click on Register
    And I fill in the user details with short password
    Then I should see an error under the password field

  Scenario: User enters the wrong confirm password
    When I click on Register
    And I fill in the user details with wrong confirm password
    Then I should see an error under the confirm password field

  Scenario: User signs in successfully
    Given I exist as a user
    And I am not logged in
    When I sign in with valid credentials
    Then I should be signed in

  Scenario: User enters wrong email
    Given I exist as a user
    And I am not logged in
    When I sign in with a wrong email
    Then I see an invalid login message
    And I should be signed out

  Scenario: User enters wrong password
    Given I exist as a user
    And I am not logged in
    When I sign in with a wrong password
    Then I see an invalid login message
    And I should be signed out
