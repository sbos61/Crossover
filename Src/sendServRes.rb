#!/usr/local/bin/ruby
################################################################################
#
#     use external send_nsca
#
require 'mail'

def resText(e)
	resT= ["PASS", "WARNING", "FAIL", "UNKNOWN"]  
	return resT[e]
end


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
#		Mail sending management
#
class SendMsg
	def initialize()
		options={
			:address				=> $gcfd.mailSmpt,
			:port					=> $gcfd.mailPort.to_i,
			:domain					=> 'localhost',
			:user_name				=> $gcfd.mailUser,
			:password				=> $gcfd.mailPwd,
			:authentication			=> 'plain',
			:enable_starttls_auto	=> true 
		}
		Mail.defaults do
		  delivery_method :smtp, options
		end
		@msgBody=''
	end

	def sendMsg( text)
		if(text !='')
			@msgBody= @msgBody+"\n"+ text
		end
	end

	def deliverMsg

		if($gcfd.mailEnable==true)
			if(@msgBody=='')
				@msgBody='No errors reported'
			end
			mail = Mail.new do
					 to $gcfd.mailToAddress
				   from $gcfd.mailFromAddress
				subject 'Automatic Alerting Mail from Crossover'
				   body @msgBody
			end
			mail.deliver
		end
	end
end

################################################################################
#
#     HTML table management
#

#
class HtmlOutput
	def initialize
		@htmlTail = '</tbody></table></body></html>'
		@htmlHead = <<END 
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html><head>
<meta http-equiv="content-type" content="text/html; charset=ISO-8859-1"><title>
END

		@htmlStyles = <<END 
</title><style type="text/css">
h1 {text-align: center; font-weight: bold;color:Black;font-family:arial;font-size:12px}
th1 {text-align: center; font-weight: bold;color:Black;font-family:helvetica;font-size:14px}
br1 {text-align: right;color:Black;font-family:arial;font-size:10px}
bl1 {text-align: left;color:Black;font-family:arial;font-size:10px}
bc {text-align: center; color: Black; font-family: Arial,Helvetica,sans-serif;font-size:12px}
table.gridtable { 
 font-family: arial; font-size:10px; border-width: 1px; border-color: #000000; 
 border-collapse: collapse; cellspacing: 1px; table-layout: fixed; width: 1050px; 
}
table.gridtable th {
 border: 1px solid black; padding: 2px; background-color: #aaaaaa;
}
table.gridtable td {
 border: 1px solid black; padding: 2px; background-color: #eaf1f7;
}
</style></head>
END

		@tableHead = <<END
<body style="color:#000000; background-color: #eaf1f7;" alink="#000099" link="#000099" vlink="#990099">
<table class="gridtable">
<thead>
<th style="width: 120px;"><h1>Date &amp; Time</h1></th>
<th style="width: 120px;"><h1>Server</h1></th>
<th style="width: 150px;"><h1>Service</h1></th>
<th style="width: 50px;"><h1>Result</h1></th>
<th style="width: 210px;"><h1>Message</h1></th>
<th style="width: 50px;"><h1>TotTime</h1></th>
<th style="width: 50px;"><h1>Twarn</h1></th>
<th style="width: 50px;"><h1>Tcrit</h1></th>
<th style="width: 100px;"><h1>TXname</h1></th>
<th style="width: 50px;"><h1>TXtime</h1></th>
<th style="width: 50px;"><h1>TXwarn</h1></th>
<th style="width: 50px;"><h1>TXcrit</h1></th>
</thead>
<tbody>
END

		@resHtml= Array.new
		@resHtml.push('<td style="background-color: #00ff00; text-align: center;"><bc>PASS</bc></td>')
		@resHtml.push('<td style="background-color: #FFFF66; text-align: center;"><bc>WARN</bc></td>')
		@resHtml.push('<td style="background-color: red; text-align: center;"><bc>FAIL</bc></td>')
		@resHtml.push('<td style="background-color: blue; text-align: center;"><bc>UNKNW</bc></td>')

	end

	def htmlSeek(fullName)
# 		tail_part= []
		fh = File.new( fullName, "r")											# open, pointer at the end
		fh.seek(-200, IO::SEEK_END)												# position near EOF
		tail=fh.read															# read to the end of file
		tail_part= tail.split("</tbody>")
		fh.close

			offset= tail_part[0].length+  File.stat( fullName).size-200				# calc offset
		File.truncate( fullName, offset-1)										# truncate the file
		
		fh = File.new( fullName, "a+")											# reopen for following processing, pointer at the end
		fh.puts "</tr>"
		return fh
	end
	
	def openHtml(path, fname, service)
		fullName=path+ fname
		if File.exists?( fullName)
			fh= htmlSeek(fullName)
		else
			fh = File.new( fullName, "wt")										# it does not exists, if exists, it will be overwritten
			fh.puts @htmlHead+ service+ @htmlStyles+ @tableHead
		end
		return fh
	end

	def addHtmlData(fh, nagserver, nagservice, state, msg)
		msg_part= []
		p2= []
		p3= []
		txr= []
		msg_part= msg.split("|")												# split message and values
		p2= msg_part[1].split(" ")												# get values for each TX

		t = Time.now
		fh.puts "<tr>\n<td>" +t.strftime("%Y-%m-%d %H:%M:%S")+ '</td><td>' +nagserver+ '</td><td>' +nagservice+ '</td>'
		fh.puts @resHtml[state] + "\n<td>" + msg_part[0] + '</td>'

		p3= p2[0].split(/(\w*)=([0-9.]*)[s;]*([0-9.]*);([0-9.]*)/)				# Whole service: separa in pezzi di numeri  lettere
		p3.shift																# skip first element
		fh.puts '<td style="text-align: right;">' + p3[1] + '</td>'				# this is the Whole servicedur
		fh.puts '<td style="text-align: right;">' + p3[2] + '</td>'				# this is the Whole servicewarn th
		fh.puts '<td style="text-align: right;">' + p3[3] + '</td>'				# this is the Whole servicefail th

		p2.shift																# delete whole service data
		ntx= p2.size
		4.times do |i|
			txr[i]=""
		end

		ntx.times do |itx|
			p3= p2[itx].split(/(\w*)=([0-9.]*)[s;]*([0-9.]*);([0-9.]*)/)		# Main TX: separa in pezzi di numeri  lettere
			p3.shift															# skip first element
			4.times do |i|
				txr[i].concat( p3[i]+ '<br>')
			end
		end

		fh.puts '<td>' + txr[0] + '</td>'										# this are the TX names
		3.times do |i|
			fh.puts '<td style="text-align: right;">' + txr[i+1] + '</td>'		# this are the TX times
		end
		fh.puts '</tr>'
	end

	def closeHtmlData( fh)
		fh.puts @htmlTail
		fh.close
	end

end
################################################################################
#
#     send result message return message
# Any kind of output: NSCA or command file direct access supported
#
def sendServRes(nagserver, nagservice, iTest, msg,  state)

	if($gcfd.screenEnable==true)
		resMsg=  resText($pfd.retState)
		msgLine= Time.now.strftime("%Y-%m-%d %H.%M.%S ")+" Service "+nagservice+" closed: run #"+iTest.to_s+" State "+resMsg
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
			ts=(Time.now.to_f ).to_i 											# read time stamp
																				# write result
			line= "["+ts.to_s+"] PROCESS_SERVICE_CHECK_RESULT;"+nagserver+";"+nagservice+";"+state.to_s+";"+msg
			$alog.lwrite(line, "DEBG")                                          # fprintf(command_file_fp,"[%lu] PROCESS_SERVICE_CHECK_RESULT;%s;%s;%d;%s\n",(unsigned long)check_time,host_name,svc_description,return_code,plugin_output);

			fcmdh = File.new( $gcfd.rwFile, "a+")
			fcmdh.puts(line)
			fcmdh.flush 
			fcmdh.close
			ret= state
		rescue
			msg= "Cannot write to command file "+ $gcfd.rwFile+": "+ $!.to_s
			$alog.lwrite(msg, "ERR_")
			$alog.lclose
			return(UNKNOWN)
		end
	end
	if($gcfd.htmlEnable==true)
		outFile=HtmlOutput.new
		htmlh=outFile.openHtml($gcfd.logPath, $gcfd.htmlOutFile, $gcfd.confGlobFile)
		outFile.addHtmlData(htmlh, nagserver, nagservice, $pfd.retState, msg)
		outFile.closeHtmlData(htmlh)
		ret= state
	end
	if(($gcfd.mailEnable==true) &&(state !=OK))															# send mail only with alarms/errors etc
		text= Time.now.strftime("%Y-%m-%d %H.%M.%S ")+" Service "+nagservice+" closed: run #"+iTest.to_s+" State "+resMsg
		$mail.sendMsg( text)
	end
	return state
end

