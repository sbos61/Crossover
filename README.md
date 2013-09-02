Crossover
=========

Crossover is a layer allowing to launch web application testing scripts of several type and gathering results in several ways.
It is written in ruby.

At the time being, it allows to run:
- Jmeter  test plans (*.jmx)
- Selenium IDE test plans (*.html)
I plan to add other tools in the near future.
Watir-webdriver is used to executed Selenium IDE plans
If you use Jmeter, you have to install and configure it.
If you use Watir Webdriver, you have to install and configure it.

A single configuration file allows to configure all features, load plans etc.

Multiple plan (even of different types) can be executed within a single run.
Beside checking for correct execution of the plan, it check for correct timing.
Each plan can have a Warning time duration and a Fail duration.
You can also specify Warning and Fail thresholds for specific steps of the plan.

Crossover has powerful log tool integrated, which allows you to check the tests execution.
You have to specify log path, and the log level.

Ouput
=====
Output can be produced in several way. 
Each output can be enabled independently of each other.
- NSCA server sending for each test (Nagios environment)
- CmdFile for integration in local Nagios system
- HTML table is under development
- screen shots can be taken where errors are detected.

How it works
============
For each plan a related .jtl file is produced.
This is native behaviour for Jmeter, while it is purposely written for Watir webdriver.
At the end of execution, the .jtl file is parsed for errors and checked against time thresholds.

