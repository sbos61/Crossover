################################################################################
# LOG definitions
#	NB
#
#
LogMode = {
	'ERR_'		=> 0,															# production mode
	'WARN'		=> 1,															# debug mode
	'INFO'		=> 2,															# test mode
	'DEBG'		=> 3															# debug mode
}
#
#	 ExitStatus	 = {
#		 'OK'		 => '0',
#		 'WARNING'	 => '1',
#		 'CRITICAL'	 => '2',
#		 'UNKNOWN'	 => '3'
#	 }
################################################################################
# LOG routines
#	NB
#
module LogRoutine

class Log

	def initialize ( status, mode)
		@state = status
		@inmemory= true
		@msgBuffer= Array.new
		@currMode= LogMode[ mode]
		return @state
	end

	def lopen(fname, mode)
		@currMode= LogMode[ mode]

		begin
			@fh = File.new( fname, "a+")
			lwrite("--------- Log file "+fname +" opened", "INFO")
			@inmemory= false

			@msgBuffer.each do |line|
				@fh.puts line
			end
			rcode= OK
		rescue
			@fh = File.new( fname+".2.log", "a+")
			lwrite("Cannot open std logfile "+fname+ "", "INFO")
			@inmemory= false

			@msgBuffer.each do |line|
				@fh.puts line
			end
			rcode= CRITICAL

			puts @state.to_s+ ": Cannot open log file /"+fname+"/"
			exit rcode
		end
		return rcode
	end

	def lwrite (msg, msgType)													# sub LogWrite ( $msg, $loglevel)
		begin
			if (msgType== nil)
				msgType = "INFO"
			end
			if ( LogMode[ msgType] <=  @currMode)
				t = Time.now
				line= t.strftime("%Y-%m-%d %H.%M.%S")+ " - "+msgType+" "+ msg
				if (@inmemory)
					@msgBuffer.push( line)
				else
					@fh.puts line
				end
			end
			return OK
		rescue
			t = Time.now
			line= t.strftime("%Y-%m-%d %H.%M.%S")+ " - ERR_ Log service internal error"+ msg
			if (@inmemory)
				@msgBuffer.push( line)
			else
				@fh.puts line
			end
			lclose()
			exit! (-1)															# abort completely
		end
	end

	def lclose ()
	  lwrite("--------- Log file closed: normal exit" , "INFO")
	  @fh.close
	end

end


end