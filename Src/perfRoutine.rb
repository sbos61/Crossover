################################################################################
# Performance and result routines
#   NB
# each line on data file is a CSV of:
#   timeStamp, dur, urlLabel, httpRes, null, null, null, applRes
#
################################################################################
# This makes the file compatible with .jtl from Jmeter

FILEMAXLEN	=10240

class PerfData

def initialize  (fileName, testMode, runMode, testType)							# full pathname filename
	@jtlfile=""
	@jtlTotal=""
	@tStarted= false
	@dataSaved= true
	@startTime= 0
	@stopTime= 0
	@testNum= 0

	@dur=0
	@urlLabel=""
	@httpRes= 'OK'																# maps to 200 response
	@httpCode= '200'
	@applRes= 'true'															# true if OK, add thread group, byte latency
	@header="timeStamp,elapsed,label,responseCode,responseMessage,threadName,dataType,success,bytes,latency"

#
# 1337265181351,547,index.php,200,OK,Thread 1-1,text,true,7020,547
#
	@applResMsg= ""																# final msg to print
	@globalRes='OK'
	@retState= OK																# string with status
																				# integer with return code
	index =  fileName.rindex('.')												# take log file full name
	if (index)
		jtlname= fileName[0 , index]											# strip off extension
	else
		jtlname= fileName														# if there is no extension, take the full name
	end
	@jtlfile= jtlname+ '.jtl'													# calculate jtl file full name
	@jtlTotal= jtlname+ '-tot.jtl'												# calculate jtl total test full name

	if !(testMode)																# if not in test mode
		@fh = File.new( @jtlfile, "w")											# if exists, it will be overwritten
		@fh.puts @header
		if(runMode==STANDALONE)													# ONLY in STANDALONE mode,
			if File.exists?( @jtlTotal)
				@fhTot = File.new( @jtlTotal, "a")								# append at the end
				@fhTot.close
			else
				@fhTot = File.new( @jtlTotal, "w")								# it does not exists, if exists, it will be overwritten
				@fhTot.puts @header
				@fhTot.close
			end
			if @fhTot then
				$alog.lwrite(("Jtl file "+@jtlTotal+" opened"), "DEBG")
			else
				@retState= UNKNOWN
				@applResMsg= "Cannot open file "+@jtlTotal
				$alog.lwrite(@applResMsg, "ERR_")
			end
		end
		if @fh then
			$alog.lwrite(("Jtl file "+@jtlfile+" opened"), "DEBG")
		else
			@retState= UNKNOWN
			@applResMsg= "Cannot open file "+@jtlfile
			$alog.lwrite(@applResMsg, "ERR_")
		end
		if(testType==JMETER)
			@fh.close
			@fh=nil
		end
	end
	return @retState
end

attr_accessor :applResMsg, :retState, :globalRes, :testNum
attr_reader :jtlfile

################################################################################
#
# save perf data on jtl file
#
def savePerfLine
# 
# timeStamp,elapsed,label,responseCode,responseMessage,threadName,dataType,success,bytes
	line= @startTime.to_i.to_s+","+@dur.to_s+","+@urlLabel+","+@httpCode+","+@httpRes+",Test_"+@testNum.to_s+",text,"+@applRes+",1,1"
	@fh.puts line
	@dataSaved = true

end

################################################################################
#
# Append data to jtl file
#
def append2JtlTotal
	@fh = File.new( @jtlfile, "r")												# open single service file
	@fh.gets																	# skip first line
	@fhTot = File.new( @jtlTotal, "a")											# append at the end
	@fhTot.puts @fh.gets(nil, FILEMAXLEN)						
	@fh.close
	@fhTot.close
end

################################################################################
#
# Check against each TX thresholds
#
def checkThreshold (pfData, stxd, nameTX, durTX)

	if (stxd.nTX> 0)															# check theresholds
		(0..stxd.nTX-1).each do |i|
			nmTX= stxd.GetTxName(i)
			cleanNmTX= nmTX.tr(' =%?*','_')										# clean up string
			if (nameTX.include? nmTX)
				if (durTX> stxd.GetCritTO(i))
					m= 'TXTO_ERR on "'+ nmTX+'": '+ sprintf("%.3f",durTX)+"s. TOcrit "+stxd.GetCritTO(i).to_s
					$alog.lwrite(m, "ERR_")
					if (@retState<CRITICAL)
						@retState= CRITICAL
						@applResMsg= m
					end
				elsif (durTX> stxd.GetWarnTO(i))
					m= 'TXTO_WRN on "'+ nmTX+'": '+ sprintf("%.3f",durTX)+"s. TOwarn "+stxd.GetWarnTO(i).to_s
					$alog.lwrite(m, "WARN")
					if (@retState<WARNING)
						@retState= WARNING
						@applResMsg= m
					end
				else
					m= 'TXPASS__ on ' +nmTX +'. Time: '+ sprintf("%.3f",durTX)
					$alog.lwrite(m,"DEBG")										# state unchanged
				end
				pfData= pfData+ cleanNmTX+ "="+sprintf("%.3f",durTX)+'s;'+stxd.GetWarnTO(i).to_s+";"+stxd.GetCritTO(i).to_s+";0 " #

				return pfData													# return when 1st match found
			end			
		end
	end
	return pfData
end

################################################################################
#
# Calculate Perf data string from data
# Time are returned in seconds
#
def CalcPerfData( iServ, warnTO, critTO)

	totTime= 0.0
	httpRes="OK"
	applRes="OK"
	perfData=""
	failure= ""
#   state= 'OK'

	begin
		@fh = File.new( @jtlfile, "r")											# read jtl file and do sums
		@fh.gets																# skip first line with headers
	rescue
		@retState = UNKNOWN
		@applResMsg= "UNKN_ERR Cannot open "+@jtlfile
		return @retState														# Cannot read file: fatal error
	end

	parms= Array.new
	@fh.each_line do |fline|
		parms= fline.split(/[\,,\n]/)

#	@header="timeStamp,elapsed,label,responseCode,responseMessage,threadName,dataType,success,bytes"
# 				0			1	2			3			4				5		6		7		8
		timeTX= parms[1].to_f/1000
		lblTX=  parms[2]
		httpTX= parms[4]
		applTX= parms[7]														# start from end: url may contains ","

		totTime+= timeTX														# sums
		if !(httpTX.include? "OK")												# error @http level
			m= "HTTP_ERR on "+ lblTX+". "+ timeTX.to_s
			$alog.lwrite(m, "ERR_")
			if (@retState <CRITICAL)											# in case of multiple errors, retunr the first
				@applResMsg= m
				@retState= CRITICAL
			end
		elsif (!applTX.include? "true")											# error @applications level
			m= "APPL_ERR on "+ lblTX+". "+ timeTX.to_s
			$alog.lwrite(m, "ERR_")
			if (@retState <CRITICAL)
				@applResMsg= m
				@retState= CRITICAL
			end
		end																		# if no error, leave prev msg

		perfData= checkThreshold(perfData, $gcfd.scfd[iServ].sTxData, lblTX, timeTX) # match against single TX info
	end

#   Error Hierarchy: FIRST error is the one reported
#   1- HTTP error
#   2- application error
#   3- single TX critical TO
#   4- global critical TO


	if (totTime<=0)																# start evaluation fo total time against global thresholds
		@retState = UNKNOWN
		@applResMsg= "UNKN_ERR Invalid total time"
		$alog.lwrite(@applResMsg, "ERR_")
	end
	if (@retState == UNKNOWN)													# final processing (global thrsh. TO etc)
		if (@applResMsg=="")
			@applResMsg= "UNKN_ERR Time: "+sprintf("%.3f",totTime)+"s"
		end
		$alog.lwrite(@applResMsg, "ERR_")
	elsif (@retState == CRITICAL)
#		@applResMsg+= " Time: "+sprintf("%.3f",totTime)+"s "
		$alog.lwrite(@applResMsg, "ERR_")
	elsif (@retState == WARNING)
		if (totTime > critTO)
			@retState = CRITICAL
			@applResMsg= "TIME_ERR Time "+sprintf("%.3f",totTime)+" s (critical "+sprintf("%.3f",critTO)+" s)"
			$alog.lwrite(@applResMsg, "ERR_")
		else
			$alog.lwrite(@applResMsg, "WARN")
		end
	else																		# if status is still OK
		if (totTime > critTO)
			@retState = CRITICAL
			@applResMsg= "TIME_ERR Time "+sprintf("%.3f",totTime)+" s (critical "+sprintf("%.3f",critTO)+" s)"
			$alog.lwrite(@applResMsg, "ERR_")
		elsif (totTime > warnTO)
			@retState = WARNING
			@applResMsg= "TIME_WRN Time "+sprintf("%.3f",totTime)+" s (warning "+sprintf("%.3f",warnTO)+" s)"
			$alog.lwrite(@applResMsg, "WARN")
		else
			@retState = OK
			@applResMsg= "PASSED__ Time "+sprintf("%.3f",totTime)
			$alog.lwrite(@applResMsg, "DEBG")

		end
	end

	@fh.close																	# close perf file
	perfData= @applResMsg+ " | time="+sprintf("%.3f",totTime)+'s;'+warnTO.to_s+';'+critTO.to_s+';0 '+perfData;

	return perfData

end

################################################################################
def tstart (url)																# sub start misuring

	if (@tStarted == true)
		$alog.lwrite(("Timer start+stop"), "DEBG")
		tstop
	end

	if (@dataSaved == false)
		savePerfLine															# write perfomance data line to file
	end

	@startUrl= url
	@applRes= 'true'
	@httpRes= 'OK'																# maps to 200 response

	@dataSaved = true
	@stopTime= 0
	@dur=0
	@urlLabel=url.tr(',','-')													# needed to support csv format
	@tStarted= true
	@startTime= Time.now.to_f* 1000

end

################################################################################
def tstop()																		# stop timer, save to file

	if (@tStarted == false)
		$alog.lwrite( "Timer stopped but not started: URL "+ $browser.url, "INFO")
	else
		@stopTime= Time.now.to_f* 1000
		@dur= (@stopTime- @startTime).to_i
		@tStarted= false
		@dataSaved = false
	end																			# check for HTTP errors
end

################################################################################
def applErr (flag, msg)															# true if NO error detected

	if flag== 'false'
		@applRes= 'false'
		@applResMsg= msg
		$alog.lwrite(msg, "ERR_")

	else
		$alog.lwrite(msg, "DEBG")
	end

	if (@tStarted == true)
		self.tstop
		$alog.lwrite("Appl. Timer stop: "+ $browser.url+". Flag: "+flag.to_s, "DEBG")
		savePerfLine															# write perfomance data line to file
	end
end

################################################################################
def httpErr (msg)																# OK true if NO error detected
	@httpRes= (msg =='OK' ? @httpRes : msg)										# HTTP msg else
end

################################################################################
def perfClose (service, logmode, warnTO, critTO)

	if(@fh!=nil)
		if (@fh)																	# non opened in test mode
			if (@tStarted == true)
				@tstop
			end
			if (@dataSaved == false)
				savePerfLine														# write perfomance data line to file
			end
			@fh.close
		end
		$alog.lwrite("Perf Data file closed: starting analysis" , "INFO")
	else
		$alog.lwrite("Perf Data file found closed: starting analysis" , "INFO")
	end
end

end

