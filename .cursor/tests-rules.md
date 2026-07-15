#Tests rules

##Unit-tests rules

- Unit-tests placed in ./tests directory
- Run tests after changes
- You can run all tests with: nvim --cmd "set rtp+=`pwd`" --headless -c "lua dofile('tests/init.lua')" -c "qa"
- The test body must clearly separate the environment preparation section and the test scenario execution section.
- Import the cpp-tools root instead of requiring its individual sub-modules, and use it to access all functionality.

###Tests on a sample project

It is kind of unit-tests

- Every test creates a temporary directory and generate a sample C++ project for test.
- Test must use autodeleted temporary directory.

###Tests for the create class tool

It's unit-tests for the create class tool

- Do not extract the repeated 'create class ...' buffer insertion into a separate function.
