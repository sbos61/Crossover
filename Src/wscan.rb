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
#
$LOAD_PATH.unshift(File.dirname(__FILE__))
#
require 'definitions.rb'

require "rexml/document"
include REXML																	# so that we don't have to prefix everything with REXML::...

require 'optparse'
require 'pp'
require 'headless'
require 'OS' 
require 'open3'
require 'timeout'
require 'net/smtp'

require 'logRoutine.rb'
require 'perfRoutine.rb'
require 'selenCommands.rb'
require 'browserCommands.rb'
require 'sendServRes.rb'														# either on file or via NSCA
require 'confRoutine.rb'
require 'commandExec.rb'
require 'sendServRes.rb'


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
	if(index) then
		fname= fname[0 , index]
	end

	cmdLineparms= Array.new
	cmdLineparms = [fname+ '.conf', options[:hlmode]]
#	$gcfd.confGlobFile= fname+ '.conf'
#	$gcfd.hlmode= options[:hlmode]

	return cmdLineparms

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
				$brws.takeScreenShot( $gcfd.logPath)							# take screenshot
			end
		end
	end
end
################################################################################
#
#		Calc service result
#
################################################################################

def calcServiceRes(iServ, iTest)

	locService= $gcfd.scfd[iServ].nagService									# do calculation on single service file
	locWarnTO= $gcfd.scfd[iServ].warnTO
	locCritTO= $gcfd.scfd[iServ].critTO
	$pfd.perfClose(locService, $brws.url.to_s)
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

	$gcfd= GlobConfData.new														# create browser interface
	parms= GetCommandLineParms()												# get command line info

	$gcfd.startUp(parms[0], parms[1])											# GLOBAL SETUP
	ret=OK

	$gcfd.testRepeat.times do |iTest|											# for each test(when in standalone mode
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
		if($gcfd.runMode==STANDALONE)	
			nowTime= Time.now.to_i
			sleepTime= [(($gcfd.pollTime)- (nowTime-servStartTime)), 0].max
			$alog.lwrite(("Sleeping for "+sleepTime.to_s+" s."), "DEBG")
			sleep(sleepTime)
		end
	end

	$gcfd.tearDown()
	exit! ret

