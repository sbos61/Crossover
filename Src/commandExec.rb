################################################################################
# Setup and lauch Jmeter routines
#   NB
# each line on data file is a CSV of:
# 
#
################################################################################
# This makes the file compatible with .jtl from Jmeter

#
def JmeterExec( i, jmxScript, jtlname, serviceTO)

#   " -jar ".$ENV{JMETER_HOME}."/bin/ApacheJMeter.jar"		from ENV
#   " -n ".
#   " -p ".$propertiesFile.	
#   " -t ".$planFile.
#   " -d ".$ENV{JMETER_HOME}.
#   " -l ".$resultsFile;

#		setup command line
jHome=$gcfd.javaHome
jmHome=$gcfd.jmeterHome


FileUtils.cd($gcfd.servConfPath)												# change working directory to keep command short
prop= "./jmeter.properties"

index= jmxScript.rindex('.')													# strip off extension
if (index)
	jmxScript= jmxScript[0,index]+".jmx"										# strip off extension
end
plan= "./"+jmxScript															# proper extension in place

																				# calculate jtl file full na
command= '"'+jHome+'"'+" -jar "+'"'+jmHome+"bin/ApacheJMeter.jar"+'"'+" -n -p "+prop+" -d "+'"'+jmHome+'"'+" -t "+plan+" -l "+jtlname

if((command.length>255) &&($gcfd.opSyst=="Windows"))
	$alog.lwrite("Jmeter command too long: "+command, "ERR_")
	return(UNKNOWN)
else
	$alog.lwrite("Jmeter launch: "+command, "DEBG") 
end

# p command

Open3.popen3(command) do |stdin, stdout, stderr, wait_thr| 						# use stdin example
	begin Timeout::timeout( serviceTO) do
			sendMsg= stdout.read
			procStatus= wait_thr.value
			if(procStatus.exitstatus!=0)
				$alog.lwrite(sendMsg, "ERR_")
			else
				$alog.lwrite(sendMsg, "DEBG")
			end
		end
		src= $gcfd.servConfPath+"jmeter.log"
		dst= $gcfd.logPath+"jmeter.log"
		FileUtils.mv(src, dst, :force => true)
	rescue
		$alog.lwrite("Error executing Jmeter: "+ command+". "+ $!.to_s, "ERR_")
		return UNKNOWN
	end
	$alog.lwrite("Jmeter script: "+plan+" executed ", "DEBG")
	return OK
end

end

def externExec

end
