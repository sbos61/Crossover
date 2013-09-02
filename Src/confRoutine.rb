################################################################################
#
#  Service transaction info (timeouts, names)
#
class ServTxData
	def initialize
		@nTX= 0
		@txName= Array.new														#
		@txCritTO= Array.new													# all values in s
		@txWarnTO= Array.new													# all values in s
	end

	attr_accessor :nTX
#   attr_accessor :txName, :txCritTO, :txWarnTO

	def GetCritTO (i)
		return @txCritTO[i]
	end

	def txCritTOAdd( s)
		@txCritTO.push( s)
	end

	def GetWarnTO (i)
		return @txWarnTO[i]
	end

	def txWarnTOAdd (s)
		@txWarnTO.push( s)
	end

	def GetTxName (i)
		return @txName[i]
	end

	def txNameAdd (s)
		@txName.push(s)
	end

end

################################################################################
#
#  Service Configuration struct init
#
class ServConfData
	def initialize
#   -------------------------------------- # general part
		@warnTO= 0
		@critTO= 0
		@totTO= 0

#   -------------------------------------- # each service part
		@testType=SELENIUM														# default mode is SeleniumIDE with Webdriver
																				# allowed: Jmeter, External
		@res= "OK"
		@nTable= 0
		@nagServer= ""
		@nagService= ""

		@fOpTable= Array.new													# table names to execute
		@sTxData= nil															# put here TX data
	end


	attr_accessor :warnTO, :critTO, :totTO
	attr_accessor :nagServer, :nagService
	attr_accessor :res, :nTable, :fOpTable, :testType, :sTxData

	def fOpTable
		@fOpTable
	end

	def opTableAdd (s)
		@fOpTable.push(s)														#
	end

	def TxDataAdd(s)
		@sTxData=s
	end

end

################################################################################
#
#  Config File parsing (each service)
#
def setupServiceConf( fh, service)

	begin

		$alog.lwrite("Service ConfData started for "+service, "INFO")
		locScfd= ServConfData.new
		locStxd= ServTxData.new

		locStxd.nTX=0
		finished= false;
		while(finished== false) do
			fline= fh.gets
			if fline.match(/^(\w+)\="(.+)"/)									#
				var= Regexp.last_match(1)
				value= Regexp.last_match(2)

				case var
				when "NagiosServer"		then locScfd.nagServer= value
				when "NagiosService"	then locScfd.nagService= value
				when "TestType"			
										case value.downcase
										when "seleniumide"	then locScfd.testType= SELENIUM
										when "jmeter"		then locScfd.testType= JMETER
										else 
											$alog.lwrite("Test type : "+var +" not supported ", "ERR_") 
										end
				when "WarnTO"			then locScfd.warnTO= value.to_f
				when "CritTO"			then locScfd.critTO= value.to_f
				when "TotTO"			then locScfd.totTO= value.to_f

				when "OpTable"			then locScfd.opTableAdd(value)
				when "TXname"
											locStxd.nTX +=1
											locStxd.txNameAdd( value)
				when "TXWarnTO"			then locStxd.txWarnTOAdd( value.to_f)
				when "TXCritTO"			then locStxd.txCritTOAdd( value.to_f)

				else
					$alog.lwrite("Unknow parms: "+var +" /value: " +value, "WARN") # vedere se fare logging
				end
			elsif fline.match(/^(\[EndServiceConf\])/)								#
				finished= true;
			end
		end

		locScfd.TxDataAdd(locStxd)
		$gcfd.scfdAdd( locScfd)
		$gcfd.nServ +=1
		$alog.lwrite("Service Config Data parsed ", "INFO")
		return OK

	rescue
		msg= "Service config file error: "+$!.to_s
		$alog.lwrite(msg, "ERR_")
		p msg
		return UNKNOWN															# Cannot read file: fatal error
	end
end


################################################################################
#
#  Global Configuration struct init
#
class GlobConfData
	def initialize

		@fname=""																# file name, non path, no ext
		@confGlobFile= ""
		@servConfPath= ""

		@logFile= ""															# full-path file name
		@logMode= 'DEBG'
		@logPath= ""

		@dateTemplate= ""
		@dirDelim= ""
		@opSyst= ""
		if(OS.windows?)
			@dirDelim= "\\"
			@opSyst= "Windows"
		else
			@dirDelim= "/"
			@opSyst="Linux"  
		end

		@brwsrType= ""
		@brwsrProfile= ""
		@testMode= false														# test mode
		@hlmode= false															# headless mode
		@headless= nil
		@res="OK"

		@start= Time.now
#   --------------------------------------- HTML config
		@htmlEnable= false
		@htmlOutFile= ""

#   --------------------------------------- # NSCA file part
		@nscaEnable=false
		@nscaExeFile=""
		@nscaConfigFile=""
		@nscaServer= ""
		@nscaPort= ""
		@newConn=false
		@conn=nil

#   --------------------------------------- #  Command file part
		@rwEnable= false
		@rwFile=""							# write directly to Nagios command queue

#   --------------------------------------- # Screen output control
		@screenEnable=true
		@screenShotEnable=false
		@screenShotFname=""
#   --------------------------------------- # Jmeter config file part
		@jmeterHome=""
		@javaHome=""

#   --------------------------------------- # runMode parms & timers
		@runMode=nil
		@pollTime=0
		@testDur=0
		@testRepeat=0
		@pageTimeOut=30						# default value
		
		@nServ= 0
		@scfd= Array.new
		
		return
	end

	attr_accessor :fname, :confGlobFile, :servConfPath, :logFile, :logMode, :logPath, :dateTemplate, :dirDelim, :opSyst
	attr_accessor :brwsrType, :brwsrProfile, :testMode, :hlmode, :headless, :res

	attr_accessor :htmlEnable, :htmlOutFile
	attr_accessor :nscaEnable, :nscaExeFile, :nscaConfigFile, :nscaServer, :nscaPort
	attr_accessor :rwFile, :rwEnable, :newConn, :conn,:screenEnable, :screenShotEnable, :screenShotFname, :javaHome, :jmeterHome
	attr_accessor :runMode, :pollTime, :testDur, :testRepeat, :pageTimeOut
	attr_accessor :nServ
	attr_reader :scfd
	
#### more complex methods

	def duration
		t = (Time.now- @start)
		return t
	end

	def scfdAdd( s)
		@scfd.push( s)
	end

	def takeScreenShot(imgName)													# take screenshot
		begin
			$browser.screenshot.save imgName
		rescue
			$alog.lwrite("Problems taking screenshots "+ imgName, "ERR_")   				# 
		end
	end 

	def ParseGlobalConfData( fh)
	begin
		$alog.lwrite("Parsing Global Configuration started ", "INFO")
		finished= false;
		while(finished== false) do
			fline= fh.gets
			if fline.match(/^(\w+)\="(.+?)"/)									#
				var= Regexp.last_match(1)
				value= Regexp.last_match(2)

# puts "var "+var+" value "+ value
				case var
				when "ServConfPath"	then $gcfd.servConfPath= value
				when "LogMode"		then $gcfd.logMode= value
				when "LogPath"		then $gcfd.logPath= value
				when "JavaHome"		then $gcfd.javaHome= value
				when "JmeterHome"	then $gcfd.jmeterHome= value
				when "DateTemplate"	then $gcfd.dateTemplate= value

				when "HTMLenable"	then $gcfd.htmlEnable= SetConfFlag( value, "HTML output : ")
				when "HTMLoutFile"	then $gcfd.htmlOutFile= value				# simple path name. Put in log dir

				when "NSCAenable"	then $gcfd.nscaEnable= SetConfFlag( value, "NSCA Mode : ")
				when "NSCAexeFile"	then $gcfd.nscaExeFile= value				# full path name
				when "NSCAconfigFile" then $gcfd.nscaConfigFile= value			# full path name
				when "NSCAserver"	then $gcfd.nscaServer= value				# name or value
				when "NSCAport"		then $gcfd.nscaPort= value					# port number

				when "ResFileEnable" then $gcfd.rwEnable= SetConfFlag( value, "RW file Mode : ")
				when "ResFile"		then $gcfd.rwFile= value					# command file for NAGIOS file mode
				when "screenEnable"	then $gcfd.screenEnable= SetConfFlag( value, "Screen output : ")
				when "screenShotEnable"	then $gcfd.screenShotEnable= SetConfFlag( value, "Enable Screen Shots : ")

				when "Browser"		then $gcfd.brwsrType= value					#
				when "Profile"		then $gcfd.brwsrProfile= value				#

				when "runMode"		then
										case value.downcase
										when "plugin"	then $gcfd.runMode= PLUGIN	# run mode: standalone or passive
										when "passive"	then $gcfd.runMode= PASSIVE	# run mode: standalone or passive
										when "standalone" then $gcfd.runMode= STANDALONE	# run mode: standalone or passive
										else 
											$alog.lwrite("RunMode : "+var +" not supported ", "WARN")   # 
										end
				when "pollTime"		then $gcfd.pollTime= value.to_i*60			# input in minutes, move to seconds 
				when "testDuration"	then $gcfd.testDur= value.to_i*60
				when "PageTO"		then $gcfd.pageTimeOut= value.to_f			# values in seconds
				else
					$alog.lwrite("Unknow parm: "+var +" /value: " +value, "WARN")   # vedere se fare logging
				end
			elsif fline.match(/^(\[EndGlobalConf\])/)							#
				finished= true;
			end
		end

		if ($gcfd.rwEnable == true) && ($gcfd.rwFile== "")						# if command file, check for file name
			msg= "Command file not set"
			$alog.lwrite(msg, "ERR_")
			p msg
			exit! UNKNOWN														# file name not set: fatal error
		end

		if ($gcfd.nscaEnable == true) && ($gcfd.nscaExeFile== "")				# if NSCA, check for command file name
			msg= "NSCA command file not set"
			$alog.lwrite(msg, "ERR_")
			p msg
			exit! UNKNOWN														# Cannot read file: fatal error
		end

		index = $gcfd.confGlobFile.rindex('.')									# take conf file
		if (index) then
			cnfname= $gcfd.confGlobFile[0 , index]								# strip off extension
		end

		index = cnfname.rindex($gcfd.dirDelim)
		if (index) then															# strip off path
			cnfname= cnfname[index+1, 9999]
		end
#   $gcfd.fname= cnfname														# save name, no path, no ext
		$gcfd.logFile= $gcfd.logPath+ cnfname+ '.log'							# calculate log file full name

		ret= OK
	rescue
		msg= "Global config file error: "+$!.to_s
		$alog.lwrite(msg, "ERR_")
		p msg
		ret= UNKNOWN															# Cannot read file: fatal error
	end
	$alog.lwrite("Global Configuration parsed: code "+ ret.to_s, "INFO")
	return ret

end

end
################################################################################
#
#  Aux configuration procedures
#
def SetConfFlag (input, msg)
	case input.downcase
	when "yes"	then retval= true													# 
	when "no"	then retval= false
	else 
		$alog.lwrite("Flag "+msg+ input +" not supported ", "WARN")   # 
	end
	return retval
end

def headlessMgr
    begin
        if ($gcfd.hlmode== true)
            $gcfd.headless = Headless.new(:dimensions => "1024x768x16")
            $gcfd.headless.start
        end
    rescue
        msg= "Cannot activate headless mode. "+ $!.to_s
        $alog.lwrite(msg, "ERR_")
        $alog.lclose
        p msg                                                                   # return message to Nagios
        exit!(UNKNOWN)
    end
end

################################################################################
#
#  Main configuration procedures
#
def ParseConfFile( confFile)
	begin
		fh = File.new( confFile, "r")
		ret= 'OK'
		$gcfd.nServ=0
		fh.each_line do |fline|
			if fline.match(/^(\[?\w+\]?)\="(.+?)"/)									#
				var= Regexp.last_match(1)
				value= Regexp.last_match(2)
				case var
				when "[StartGlobalConf]"		then ret= $gcfd.ParseGlobalConfData( fh)
				when "[StartServiceConf]"		then ret= setupServiceConf( fh, value)	# add service name
				else
					$alog.lwrite("Out positioned parm: "+var +" /value: " +value, "WARN")   # vedere se fare logging
				end
			end
	# puts "var "+var+" value "+ value
		end
	rescue
		msg= "Service config file error: "+$!.to_s
		$alog.lwrite(msg, "ERR_")
		p msg
		return UNKNOWN															# Cannot read file: fatal error
	end

	if (($gcfd.runMode== nil)|| ($gcfd.runMode== PASSIVE))						# default is old stype passive mode
		$gcfd.runMode= PASSIVE
		$gcfd.testRepeat=1
		$gcfd.testDur=1
		$gcfd.pollTime=1
	elsif( $gcfd.runMode== PLUGIN)
		$gcfd.testRepeat=1
		$gcfd.testDur=1
		$gcfd.pollTime=1
		$gcfd.nServ=1															# in plugin mode, only one service allowed
		$gcfd.screenEnable=false
	elsif(( $gcfd.pollTime==0)|| ($gcfd.testDur==0))
		raise "RunMode configuration error: "+$gcfd.pollTime.to_s+" , "+$gcfd.testDur.to_s
	else
		$gcfd.runMode= STANDALONE
		$gcfd.testRepeat=($gcfd.testDur / $gcfd.pollTime).round
		$gcfd.pollTime= $gcfd.pollTime											# move to seconds
	end
	headlessMgr()
	return ret
end
