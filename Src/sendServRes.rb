#!/usr/local/bin/ruby
################################################################################
#
#     use external send_nsca
#

class SendNSCA
	def initialize( args)
		@command= args[:command]
		@hostname= " -H "+args[:host]+" "
		@timeOut=10
		@nscaConfigFile=" -c "+args[:confFile]+" "
		@port= " -p "+args[:port]+" "
		@nagserver=""
		@nagservice=""
		@data=""
		@status=0
		@fullCmd=@command+@hostname+ @port+ " -to "+@timeOut.to_s+@nscaConfigFile
		@resString=""
	end

	def sendNSCA(nagserver, nagservice, data, status)
		@resString= nagserver+"\t"+ nagservice+"\t" +status.to_s+"\t"+data+"\n"

		$alog.lwrite(@resString, "DEBG")
		Open3.popen3(@fullCmd) do |stdin, stdout, stderr, wait_thr| 				# use stdin example
			stdin.write(@resString)
			stdin.close_write

			begin Timeout::timeout(5) do
					sendMsg= stdout.read
					procStatus= wait_thr.value
					if(procStatus.exitstatus!=0)
						$alog.lwrite(sendMsg, "ERR_")
					else
						$alog.lwrite(sendMsg, "DEBG")
					end
				end
				return(OK)
			rescue Timeout::Error
#			rescue
				$alog.lwrite("Timeout error sending to NSCA server: "+ $!.to_s, "ERR_")
				return(UNKNOWN)
			end
		end
	end
end

################################################################################
#
#     send result message return message
# Any kind of output: NSCA or command file direct access supported
#
def sendServRes (nagserver, nagservice, iTest, msg,  state)

	if($gcfd.screenEnable==true)
		resMsg= ($pfd.retState==0? 'PASS': 'FAIL')
		msgLine= Time.now.strftime("%Y-%m-%d %H.%M.%S ")+resMsg+" Service "+nagservice+" closed: run #"+iTest.to_s+", state "+errText($pfd.retState)
		p msgLine
	end
	if($gcfd.nscaEnable==true)
		begin
			if(($gcfd.newConn)==false)
				$gcfd.conn= SendNSCA.new(:command => $gcfd.nscaExeFile,
					:host => $gcfd.nscaServer,
					:port => $gcfd.nscaPort,
					:confFile => $gcfd.nscaConfigFile)
				$gcfd.newConn=true
			end

			ret= $gcfd.conn.sendNSCA(nagserver, nagservice, msg, state)
		rescue
			msg= "Cannot send NSCA data to server "+ $gcfd.nscaServer+": "+ $!.to_s
			$alog.lwrite(msg, "ERR_")
			$alog.lclose
			p msg																# return message to Nagios
			return(UNKNOWN)
		end
	end
	if($gcfd.rwEnable==true)
		begin
			ts= (Time.now.to_f ).to_i 											# read time stamp
																				# write result
			line= "["+ts.to_s+"] PROCESS_SERVICE_CHECK_RESULT;"+nagserver+";"+nagservice+";"+state.to_s+";"+msg
			$alog.lwrite(line, "DEBG")                                          # fprintf(command_file_fp,"[%lu] PROCESS_SERVICE_CHECK_RESULT;%s;%s;%d;%s\n",(unsigned long)check_time,host_name,svc_description,return_code,plugin_output);

			fcmdh = File.new( $gcfd.rwFile, "a+")
			fcmdh.puts(line)
			fcmdh.flush 
			fcmdh.close                                                         # chiudi e ritorna
		rescue
			msg= "Cannot write to command file "+ $gcfd.rwFile+": "+ $!.to_s
			$alog.lwrite(msg, "ERR_")
			$alog.lclose
			return(UNKNOWN)
		end
	end
	if($gcfd.htmlEnable==true)
		$alog.lwrite("HTML file to be implemented", "INFO")
	end
end

