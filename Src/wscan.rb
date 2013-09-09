#!/usr/local/bin/ruby
################################################################################
#
#	Nagios Ruby WebDriver plugin.
#
#	By Sergio Boso		www.bosoconsulting.it
#
#	This software is covered by GPL license
#	It is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
#	WARRANTY OF DESIGN, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE.
#	You can use and modify it but you must keep this message in it.
#
#
#	Wscan  - uses NSCA architecture to Nagios
#			- executes multiple service checks on multiple host in sequence
#			- executes multiple Selenium IDE tables per service.
#
#	parameters:
#		-p --config file:
#					Include the ABSOLUTE Path (file .conf)
#		-x --xvfb: run head less mode


################################################################################
# status constant
#
# add source location
$LOAD_PATH.unshift(File.dirname(__FILE__))
#

OK			=0
WARNING		=1
CRITICAL	=2
UNKNOWN		=3
def errText(e)
	errT= ["OK", "WARNING", "CRITICAL", "UNKNOWN"]  
	return errT[e]
end

PLUGIN		=0
PASSIVE		=1
STANDALONE	=2

SELENIUM	=0
JMETER		=1
EXTERNAL	=2

require 'watir-webdriver'														#open a browser WD mode
require 'watir-webdriver-performance'
require "rexml/document"

include REXML																	# so that we don't have to prefix everything with REXML::...

require 'optparse'
require 'pp'
require 'headless'
require 'OS' 
require 'open3'
require 'timeout'

require 'logRoutine.rb'
require 'perfRoutine.rb'
require 'wdCommands.rb'
require 'sendServRes.rb'														# either on file or via NSCA
require 'confRoutine.rb'
require 'commandExec.rb'


#def helpLog( msg)
#	fname= '/etc/nagios/logs/google.log'
#	fh = File.new( fname, "a+")
#	fh.puts Time.now.strftime("%Y-%m-%d %H.%M.%S")+ '  '+ msg
#	fh.close
#end


################################################################################
#
#  Command Line parsing
#
#
def GetCommandLineParms()

	hlp= "Usage:\n\n -p Config File name\n -x Headless mode\n"

	options = {}
	optparse = OptionParser.new do |opts|										# TODO: Put command-line options here
		opts.banner= hlp														# This displays the help screen, all programs are
																				# assumed to have this option.
		opts.on( '-h', '--help') do
			puts hlp
			exit
		end

		options[:conffile] = nil
		opts.on( '-p', '--config FILE','Test Plan FILE') do |fname|
			options[:conffile]= fname
		end

		options[:hlmode] = nil
		opts.on( '-x', '--xvfb', "Use headless mode") do |to|
			options[:hlmode]= true|| nil
		end
	end

	optparse.parse!																# Parse the command-line.
	fname= options[:conffile]
	index = fname.rindex('.')
	if (index) then
		fname= fname[0 , index]
	end

	$gcfd.confGlobFile= fname+ '.conf'
	$gcfd.hlmode= options[:hlmode]


end

################################################################################
#
#  Configuration management
#   parses command line options
#   open & parses .conf file
#   open .log file
#	open Browser
#
def setUpGlobalConf ()
	GetCommandLineParms()														# get command line info
	ParseConfFile( $gcfd.confGlobFile)

	$alog.lopen($gcfd.logFile, $gcfd.logMode)
	$alog.lwrite("Config data read from "+$gcfd.confGlobFile, "INFO")

	begin
		if ($gcfd.hlmode== true)
			$gcfd.headless = Headless.new(:dimensions => "1024x768x16")
			$gcfd.headless.start
		end
	rescue
		msg= "Cannot activate headless mode. "+ $!.to_s
		$alog.lwrite(msg, "ERR_")
		$alog.lclose
		p msg																	# return message to Nagios
		exit!(UNKNOWN)
	end

	begin
		if !($gcfd.testMode== true)												# not in test mode
			if $gcfd.brwsrType[0..1].downcase =="ie"
				$browser= Watir::Browser.new:ie
				$alog.lwrite("Explorer opened ", "INFO")
			elsif $gcfd.brwsrType[0..1].downcase =="ch"
				$browser= Watir::Browser.new:chrome
				$alog.lwrite("Chrome opened ", "INFO")
			else
				pf= $gcfd.brwsrProfile
				if pf ==""
					$browser= Watir::Browser.new:firefox						# default is Firefox
				else
					$browser= Watir::Browser.new:firefox, :profile => pf		# Firefox with profile
				end
				$alog.lwrite("Firefox opened with profile /"+pf+"/", "INFO")
			end
			$browser.driver.manage.timeouts.page_load = 60						# increase page timeout
		end

		$gcfd.res= "OK"

	rescue
		msg= "Cannot open browser. "+ $!.to_s
		$alog.lwrite(msg, "ERR_")
		if ($gcfd.hlmode== true)
			$gcfd.headless.destroy
		end
		$alog.lclose
		p msg																	# return message to Nagios
		exit!(UNKNOWN)

	end

end

################################################################################
#
#  Configuration management
#   clean up and close
#
def closeGlobConf ()

	$browser.close
	if ($gcfd.hlmode== true)
		$gcfd.headless.destroy
	end

	msgLog ="Durata scan: "+ sprintf("%.3f",$gcfd.duration)+ "s"
	$alog.lwrite(msgLog, "INFO")
end


################################################################################
#
#  Operation table management
#	receives the file name "fconfig" parameter
#	load table data
#
################################################################################
#

def processOpTable ( optable)

	begin
		doc = Document.new File.new( optable, "r")

	rescue
		$alog.lwrite("CANNot open table: "+optable, "ERR_")
		return CRITICAL
	end
	$alog.lwrite("Table "+optable+" opened", "INFO")


#   root = doc.root
	title= ""
	urlBase = doc.elements["*/head/link"  ].attributes["href"]
	title =  XPath.first(doc, "*//title")
	$alog.lwrite("Base URL "+ urlBase+ " Title "+title.text, "DEBG")

	i=0
	cmds = []																	#create an arry of commands
	doc.elements.each( "//tbody/tr/td") { |e|
		cmds[i] = e.text
		if cmds[i] == nil then
			cmds[i]  =""
		end
		i=i+1
	}

	elemNum= (i/3)
	0.upto(elemNum-1) {|j|														# pass each command line
		rcode= processElement( urlBase, cmds[j*3], cmds[j*3+1], cmds [(j*3)+2])
		if rcode != OK then														# if OK proceed with processing
			$alog.lwrite("Command table "+ optable+ " aborted on step "+cmds[j*3], "INFO")
			return rcode
		end
	}

	$alog.lwrite("Command table "+ optable+ " finished ", "INFO")
	return OK

end

################################################################################
#
#		Exec service
#
################################################################################

def execService(iServ, iTest)
	if( $gcfd.testMode==true)													# in test mode
		return																	# do not do just service, just use .jtl file 
	end
	if($gcfd.scfd[iServ].testType==JMETER)										# start Jmeter management
		$pfd.applResMsg= JmeterExec(iServ, $gcfd.scfd[iServ].fOpTable[0], $pfd.jtlfile, $gcfd.scfd[iServ].totTO)

	elsif($gcfd.scfd[iServ].testType==EXTERNAL)									# start external command management
#		$pfd.applResMsg= ExternExec($gcfd[iServ]....)
	elsif($gcfd.scfd[iServ].testType==SELENIUM)									# default is webdriver
		$gcfd.scfd[iServ].fOpTable.each do |table|	 							# fixed for each group
			rcode= processOpTable( $gcfd.servConfPath+ table)					# workout each instruction table
			if(($gcfd.screenShotEnable== true)&&( rcode!=OK))
				imgName= $gcfd.logPath+$gcfd.scfd[iServ].nagService+"_"+Time.now.to_i.to_s+".png"
				$gcfd.takeScreenShot(imgName)									# take screenshot 
				$alog.lwrite(("Image saved in "+imgName), "DEBG")
			end
		end
	end
end
################################################################################
#
#		Calc service result
#
################################################################################

def calcServiceRes (iServ, iTest)

	locService= $gcfd.scfd[iServ].nagService									# do calculation on single service file
	locWarnTO= $gcfd.scfd[iServ].warnTO
	locCritTO= $gcfd.scfd[iServ].critTO
	$pfd.perfClose(locService, $gcfd.logMode, locWarnTO, locCritTO)
	$pfd.applResMsg= $pfd.CalcPerfData(iServ, locWarnTO, locCritTO)

	if($gcfd.runMode==STANDALONE)
		$pfd.append2JtlTotal()
	else																		# only PLUGIN /PASSSIVE probe for Nagios...
		p $pfd.applResMsg														# print msg to console
	end
	return sendServRes( $gcfd.scfd[iServ].nagServer, $gcfd.scfd[iServ].nagService, iTest, $pfd.applResMsg, $pfd.retState) # process output to Nagios or whatever
end

################################################################################
#
#		Beginning of main procedure
#
################################################################################

	$alog=LogRoutine::Log.new(OK, "DEBG")										# open log file
	$gcfd= GlobConfData.new														# create browser interface
	setUpGlobalConf()
	ret=OK
	$gcfd.testRepeat.times do |iTest|											# for each test (when in standalone mode
		servStartTime= Time.now.to_i											# time stamp in seconds
		$gcfd.nServ.times do |iServ|											# for each service

			$pfd=PerfData.new($gcfd.logPath+$gcfd.scfd[iServ].nagService, 
				false, 
				$gcfd.runMode, 
				$gcfd.scfd[iServ].testType)										# get results file name from service name
			$pfd.testNum=iTest													# keep progr test number
			execService(iServ, iTest)
			ret= calcServiceRes(iServ, iTest)
			if(ret==OK)
				ret= $pfd.retState
			end
		end
		if ($gcfd.runMode==STANDALONE)	
			nowTime= Time.now.to_i
			sleepTime= [(($gcfd.pollTime)- (nowTime-servStartTime)), 0].max
			$alog.lwrite(("Sleeping for "+sleepTime.to_s+" s."), "DEBG")
			sleep(sleepTime)
		end
	end

	closeGlobConf()
	$alog.lclose
	exit! ret

