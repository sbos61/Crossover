################################################################################
#
#	Ruby WebDriver plugin.
#	Watir single commands functions
#
################################################################################
# 
# Abstract the browser object. Uses $pfd objects
#
require 'watir-webdriver'														#open a browser WD mode
require 'watir-webdriver-performance'


TIMETICK		=0.2
TIMETICKSHORT	=0.2
StartTO			=20

class GenBrowser < Watir::Browser

	def initialize (type, profile )
		@status= nil
		@brws= nil

		if(type== 'ie')
			brtype= :ie
		elsif(type== 'ch')
			brtype= :chrome
		else
			brtype= :firefox
		end


		begin Timeout::timeout( StartTO) do
			if profile ==''
				@brws= Watir::Browser.new brtype
			else
				@brws= Watir::Browser.new brtype, :profile => profile		# Firefox with profile
			end
			$alog.lwrite( brtype.to_s+ " opened with profile /"+profile+"/", "INFO")
			end
			$gcfd.res= 'OK'
			@status= OK
		rescue
			msg= "Cannot open browser. "+ $!.to_s
			$alog.lwrite(msg, "ERR_")
			@status= CRITICAL
		end
		@pageTimer= 0
		@pageTimeOut=$gcfd.pageTimeOut
		if(type!= 'ch')
			@brws.driver.manage.timeouts.page_load = @pageTimeOut							# increase page timeout
		end
		return @brws
	end

	attr_reader   :status

#	def close
#		@brws.close
#	end

################################################################################
# 	Timeout management
#
	def setPageTimer()
		@pageTimer= Time.now.to_i+ @pageTimeOut
	end

	def clearPageTimer()
		@pageTimer= Time.now.to_i-1												# the timer is FALSE for sure
	end


	def getPageTimer()															# TRUE if finished
		return(@pageTimer <Time.now.to_i)										# FALSE if not
	end

################################################################################
	def checkCode( code, msg)
		if(@brws.text.include? code.to_s) ||(@brws.text.downcase.include? msg)	# check 404 
			res= code
		elsif(@brws.title.include? code.to_s) ||(@brws.title.downcase.include? msg)	# check 404 
			res= code
		else
			res= OK 
		end
		return res
	end

################################################################################
	def checkHTTPerr(tag, tvalue)
		if(res= @brws.checkCode( 404, "not found") !=OK)						# uses $browsers global
			msg= "HTTP_ERR: 404 not found on URL "+ $brws.url.to_s
#			@httpCode= "404"
#			@httpRes= 'Not found'
		elsif(res= @brws.checkCode( 500, "server") !=OK)						# check 500
			msg= "HTTP_ERR: 500 internal server error on URL "+ $brws.url.to_s
#			@httpCode= '500'
#			@httpRes= 'Internal server error'
		end
		return [res, msg]
	end

################################################################################
	def click(selector, tvalue)
		url= @brws.url.to_s															# start timer in any case
		res= OK																		# default is OK
		if(selector== :link)
			selector=:text
		end

		begin
			if selector==:xpath || selector==:css
				if @brws.element(selector=>tvalue).exists?
					$alog.lwrite(("Clck on element /"+selector.to_s+"/"+tvalue+"/"), "DEBG")	# NEW page
					$pfd.tstart( url)
					@brws.element(selector=> tvalue).click
				end
#			elsif @brws.input(selector=>tvalue).exists?
#				$alog.lwrite(("Clck on button /:"+selector.to_s+"/"+tvalue+"/"), "DEBG")	# NEW page
#				$pfd.tstart( url)
#				@brws.input(selector=> tvalue).click

			elsif(@brws.checkbox(selector=>tvalue).exists?)
				$alog.lwrite(("Clck on checkbox /:"+selector.to_s+"/"+tvalue+"/"), "DEBG")
				@brws.checkbox(selector=> tvalue).set
				sleep TIMETICK													# small sleep to let objects appear

			elsif(@brws.radio(selector=>tvalue).exists?)
				$alog.lwrite(("Clck on Radio /:"+selector.to_s+"/"+tvalue+"/"), "DEBG")
				@brws.radio(selector=> tvalue).set
				sleep TIMETICK													# small sleep to let objects appear

			elsif @brws.button(selector=>tvalue).exists?
				$alog.lwrite(("Clck on button /:"+selector.to_s+"/"+tvalue+"/"), "DEBG")	# NEW page
				$pfd.tstart( url)
				@brws.button(selector=> tvalue).click

			elsif(@brws.link(selector=>tvalue).exists?)
				$alog.lwrite(("Clck on link /:"+selector.to_s+"/"+tvalue+"/"), "DEBG")		# NEW page
				$pfd.tstart( url)
				@brws.link(selector=> tvalue).click

			elsif(@brws.image(selector=>tvalue).exists?)
				$alog.lwrite(("Clck on image /:"+selector.to_s+"/"+tvalue+"/"), "DEBG")
				$pfd.tstart( url)                                                      		# NEW page
				@brws.image(selector=> tvalue).click

			elsif(@brws.span(selector=>tvalue).exists?)
				$alog.lwrite(("Clck on span /:"+selector.to_s+"/"+tvalue+"/"), "DEBG")
				@brws.span(selector=> tvalue).click

			elsif(@brws.div(selector=>tvalue).exists?)
				$alog.lwrite(("Clck on div /:"+selector.to_s+"/"+tvalue+"/"), "DEBG")
				$pfd.tstart( url)
				@brws.div(selector=> tvalue).click

			else
				$pfd.applRes(false, "Click on unknown obj. Selector: /"+ selector.to_s+"/ value: /"+tvalue+"/. ", url)
				res= CRITICAL
			end
		rescue
			$pfd.applRes(false, "Click: CANnot find obj: tag /"+ selector.to_s+"/ value /"+tvalue+"/"+$!.to_s, url)
			res= CRITICAL
		end
		return res
	end

################################################################################
	def goto (url)
		$pfd.tstart( url)
		begin
			@brws.goto( url)
			return OK
		rescue
			$pfd.applRes(false,("Cannot reach URL. Parm: /"+url+"/"), url.to_s)
			return CRITICAL
		end
		return CRITICAL
	end

################################################################################
	def selectList(selector, tvalue, values)

		url= @brws.url.to_s
		loc= selector.to_s+" with value:/"+tvalue+"/ and values "+values.join(',')
		begin
			@brws.select_list(selector=>tvalue).select(values[0])						# single value
			$pfd.applRes(true, "OK: Selected list: "+loc, url)
			res=OK
		rescue
			$pfd.applRes(false, "CANnot select list "+loc+" : "+$!.to_s, url)
			res=CRITICAL
		end

	end

################################################################################
	def typeText(selector, tvalue, text)
		begin

			if @brws.text_field(selector, tvalue).exist?
				@brws.text_field(selector, tvalue).clear
				@brws.text_field(selector, tvalue).set(text)
				$alog.lwrite(("Wrote /"+text+"/ to box "+selector.to_s+","+tvalue), "DEBG")
				sleep TIMETICK														# small sleep to let objects appear
				return OK
			else
				$pfd.applErr(false, "CANnot find box "+selector.to_s+","+tvalue+": "+$!.to_s, @brws.url.to_s)
				return CRITICAL
			end
		rescue
			$pfd.applRes(false, "CANnot write /"+text+"/ to box "+selector.to_s+","+tvalue+": "+$!.to_s, @brws.url.to_s)
			return CRITICAL
		end
	end

################################################################################
	def dragAndDrop(tag, tvalue, from, to)

		url= @brws.url.to_s
		begin
			el= @brws.element(tag, tvalue)
			$pfd.tstart(url)
			el.drag_and_drop_by( from, to)
			$pfd.applRes(true, "Drag and drop "+par1+" by "+par2, url)
			sleep TIMETICK														# small sleep to let objects appear
			return OK
		rescue
			$pfd.applRes(false,"DragAndDrop failed. Values: /"+tag.to_s+"/"+tvalue+"/ "+$!.to_s, url)
			return CRITICAL
		end
	end

################################################################################
# This is unified waitfor , verifyText, verify Title etc
	def lookFor(type, tvalue, wait)

		url= @brws.url.to_s
		$alog.lwrite(("WaitForElement "+type.to_s+" with value /"+tvalue+"/"), "DEBG")
		begin
			(wait  ? self.setPageTimer() : self.clearPageTimer()) 				# set or clear the page timer
			finished= false
			begin
				case type
				when :title
					if(@brws.title.include? tvalue)			then finished= true; end
				when :text
					if(@brws.text.include? tvalue)			then finished= true; end
				when :link
					if(@brws.link(:text, tvalue).exists?)	then finished= true; end
				when :span, :css, :id, :element
					if(@brws.element(type, tvalue).exists?)	then finished= true; end
				when :name
					if(@brws.button(:name, tvalue).exists?)
						finished= true;
					elsif(@brws.select_list(:name, tvalue).exists?)
						finished= true;
					else
						$pfd.applRes(false,"CANnot find :name with value "+tvalue, url)
						return CRITICAL
					end
				else
					$pfd.applRes(false,"CANnot find selector "+type.to_s+" with value "+tvalue, url)
					return CRITICAL
				end
				if (!finished) then sleep TIMETICK end
			end until (self.getPageTimer() || finished)
			if(finished)
				$pfd.applRes(true,"OK: "+type.to_s+" found:/"+tvalue+"/", url)
				return OK
			else
				$pfd.applRes(false, type.to_s+" not found. Value: /"+tvalue+"/ "+$!.to_s, url)
				return CRITICAL
			end
		rescue
			$pfd.applRes(false, type.to_s+" not selectable. Value: /"+tvalue+"/ "+$!.to_s, url)
			return CRITICAL
		end
		return CRITICAL																	#  mark error but proceed w/ processing
	end

################################################################################
# This is unified test function
	def checkFor(type, tvalue)

		url= @brws.url.to_s
		$alog.lwrite(("Checking element "+type.to_s+" with value /"+tvalue+"/"), "DEBG")
		begin

			found= false
			case type
				when :title
					if(@brws.title.include? tvalue)			then found= true; end
				when :text
					if(@brws.text.include? tvalue)			then found= true; end
				when :link
					if(@brws.link(:text, tvalue).exists?)	then found= true; end
				when :span, :css, :id, :element
					if(@brws.element(type, tvalue).exists?)	then found= true; end
				when :name
					if(@brws.button(:name, tvalue).exists?)
						found= true;
					elsif(@brws.select_list(:name, tvalue).exists?)
						found= true;
					else
						$pfd.applRes(true,"CANnot find :name with value "+tvalue, url)
						return OK
					end
				else
					$pfd.applRes(true,"CANnot find selector "+type.to_s+" with value "+tvalue, url)
					return OK
			end

			if(found)
				$pfd.applRes(true,"Check: "+type.to_s+" found:/"+tvalue+"/", url)
				return OK
			else
				$pfd.applRes(true, type.to_s+" not found. Value: /"+tvalue+"/ "+$!.to_s, url)
				return CRITICAL
			end
		rescue
			$pfd.applRes(false, type.to_s+" not selectable. Value: /"+tvalue+"/ "+$!.to_s, url)
			return CRITICAL
		end
		return CRITICAL																	#  mark error but proceed w/ processing
	end

################################################################################
	def radioSet(tag, tvalue)
		begin
			@brws.radioset(tag, tvalue).set
			$alog.lwrite(("Radio button "+tag.to_s+" set with value="+tvalue+"."), "DEBG")
			return OK
		rescue
			$pfd.applRes(false, "Radio Button "+tag.to_s+" not selectable. Value: "+tvalue+" "+$!.to_s, @brws.url.to_s)
			return CRITICAL
		end
	end

################################################################################
	def takeScreenShot()														# take screenshot
		begin
			imgName= $gcfd.logPath+@bwrs.url.tr(' =%?*/\\:','_')+Time.now.to_i.to_s+'.png'
			@brws.screenshot.save imgName
			$alog.lwrite(("Image saved in "+imgName), "DEBG")
		rescue
			$alog.lwrite("Problems taking screenshots "+ imgName, "ERR_")   				#
		end
	end

################################################################################
	def url
		@brws.url
	end

################################################################################
	def savePage()
		begin

			fileName= $gcfd.logPath+@brws.url.tr(' =%?*/\\:','_')+Time.now.to_i.to_s+'.html'
			File.open(fileName, "w") do |file|
				file.write(@brws.html)
			end
			$alog.lwrite("HTML page  saved in "+ fileName, "DEBG")
		rescue
			$alog.lwrite("Problems saving page "+ fileName, "ERR_")   				#
		end

	end

################################################################################
	def enterSpecChar(tag, tvalue, spChSym)
		begin
			@brws.text_field(tag, tvalue).send_keys(spChSym)
			$alog.lwrite('Sent char :' +spChSym.to_s+ ' to field '+tag.to_s+'/'+tvalue+'/', "DEBG")
		rescue
			$alog.lwrite('CANnot send char' +spChSym.to_s+ ' to field '+tag.to_s+'/'+tvalue+'/', "ERR_")   				#
		end
	end

################################################################################
	def close
		@brws.close
		$alog.lwrite("Browser closed!", "DEBG")
	end

	################################################################################
	def WaitTTime(rangeTO)
		sleepTime= rand(rangeTO[0]..rangeTO[1])
		$alog.lwrite(("Sleeping for "+sleepTime.to_f.to_s+" s."), "DEBG")
		sleep(sleepTime)

	end

end
