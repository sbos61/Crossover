Crossover
=========

Crossover is a layer allowing to launch web application testing scripts of several type and gathering results in several ways.
It is written in ruby.

At the time being, it allows to run:
- Jmeter  test plans (*.jmx)  (aka TestType="Jmeter" tests)
- Selenium IDE test plans (*.html) (aka TestType="SeleniumIDE" tests)
I plan to add other tools in the near future.
Watir-webdriver is used to executed Selenium IDE plans
If you use Jmeter, you have to install and configure it.
If you use Watir Webdriver, you have to install and configure it.

A single configuration file allows to configure all features, load plans etc.

Multiple plan (even of different type) can be executed within a single run.
Beside checking for correct execution of the plan, it check for correct timing.
Each plan can have a Warning time duration and a Fail duration.
You can also specify Warning and Fail thresholds for specific steps of the plan.

Crossover has powerful log tool integrated, which allows you to check the tests execution.
You have to specify log path, and the log level.

Output
=====
several Output types can be produced. 
Each output can be enabled independently of each other:
- you can send results to NSCA server for each test (Nagios environment)
- you can print a single line results on screen for each test 
- you can have an HTML table with the result of all tests
- you can have an email bearing all the alarms within each test run
- screen shots can be taken where errors are detected.
- .jtl files are left behind for each plan and they are overwritten when executing the next test.
  When running in "standAlone" mode (see below) a "plan name"-tot.jtl file is produced, holding all the results.
  This file is never overwritten (always appended).

Installation
============
You have to download & install Java & Jmeter:
 http://jmeter.apache.org/usermanual/get-started.html#install
You have to download/install:
 Ruby 1.9.3
You have to install the following GEMs:
 childprocess
 ffi
 headless
 json
 mail
 multi_json
 open4
 os
 rubyzip
 send_nsca
 selenium-webdriver
 watir-webdriver
 watir-webdriver-performance
 websocket
 wopen3
 xml-simple

 
How it works
============
At the beginning of the test, the config file is read, then is starts executing the plans one at a time.

You can select 3 different modes (aka runMode):
"Plugin"		This is used to be launched by Nagios as a local probe in active way.
				Data results are printed on the screen, as required for Nagios plugins.
				Only the first one plan is executed.
"passive"		passive Nagios probe.
				This is used to launch the test periodically (usually via crontab) and send result to Nagios via NSCA.
				All tests are executed.
"standAlone"	This is used to launch manually a cycling monitor. All tests are executed.
				You must specify:
					pollTime="2"		# minutes between polling
					testDuration="8"	# test total duration (minutes)
				This can be useful to launch a monitoring campaign, without having a monitor system involved.
  
For each plan a related .jtl file is produced.
This is native behaviour for Jmeter, while it is purposely written for Watir webdriver.
At the end of execution, the .jtl file is parsed for errors and checked against time thresholds.

You can select the type of browser you want to use.
I tested with Firefox, Explorer, Chrome. Of course, it must be present on the test system.
The browser is created when starting the test, and destroyed at the end. So the same browser is used throughout the whole test. 
This is a huge advantage in terms of time.

About Firefox, I recommend installing the ESR version, with auto-upgrade disabled.
Also, with Firefox, you can select the profile you want to use. (Webdriver is the name you find in the reference config file).
This make the startup faster, and allows you to manually configure the user preferences.
If you select a profile, you have to create it manually.
If you do not select a profile, a temporary profile is created and it is destroyed at the end of the test.


How to launch it
================
(in windows)
wscan.rb -p .\Cfg\wscan_2-0complete.conf

At this time the only other option is:
  -x enable headless mode (Linux only)
