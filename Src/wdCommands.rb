################################################################################
#
#	Nagios Ruby WebDriver plugin.
#	Watir single commands functions
#
################################################################################
#
#
TIMETICK	=0.2
TIMETICKSHORT	=0.2

#
#

def click ( par1 )																# need do act different
																				# based on the type of object passed
	ftype= []
	ftype= par1.split(/=/, 2)
	tag= ftype[0]
	tvalue= ftype[1]
	if tag=="link"
		tag="text"																# ????
	elsif tag=~/^\/\/div/
		tag= "xpath"
		tvalue= par1
	end

	res= OK																		# default is OK
	$alog.lwrite(("Clck obj: "+tag+" from /"+par1+"/"), "DEBG")					# track obj

	$pfd.tstart( par1)															# start timer in any case

	begin
		if tag=="xpath" || tag=="css"
			if $browser.element(tag.to_sym=>tvalue).exists?
				$alog.lwrite(("Clck on /"+tag+" /"+tvalue+"/"), "DEBG")			# NEW page
#				$browser.div(tag.to_sym=> tvalue).click
				$browser.element(tag.to_sym=> tvalue).click
			else
				$pfd.applErr('false', ("Clck unknown obj. Selector:/"+ tag+"/ xpath:-"+tvalue+"-"))
				res= CRITICAL
			end

		else
			if $browser.button(tag.to_sym=>tvalue).exists?
				$alog.lwrite(("Clck on button /:"+tag+"/"+tvalue+"/"), "DEBG")	# NEW page
				$browser.button(tag.to_sym=> tvalue).click

			elsif ($browser.link(tag.to_sym=>tvalue).exists?)
				$alog.lwrite(("Clck on link /:"+tag+"/"+tvalue+"/"), "DEBG")	# NEW page
				$browser.link(tag.to_sym=> tvalue).click

			elsif ($browser.image(tag.to_sym=>tvalue).exists?)
				$alog.lwrite(("Clck on image /:"+tag+"/"+tvalue+"/"), "DEBG")
				$browser.image(tag.to_sym=> tvalue).click

			elsif ($browser.checkbox(tag.to_sym=>tvalue).exists?)
				$alog.lwrite(("Clck on checkbox /:"+tag+"/"+tvalue+"/"), "DEBG")
				$browser.checkbox(tag.to_sym=> tvalue).set
				sleep TIMETICK													# small sleep to let objects appear

			elsif ($browser.radio(tag.to_sym=>tvalue).exists?)					# MUST be the last one
				$alog.lwrite(("Clck on Radio /:"+tag+"/"+tvalue+"/"), "DEBG")
				$browser.radio(tag.to_sym=> tvalue).set
				sleep TIMETICK													# small sleep to let objects appear

			elsif ($browser.span(tag.to_sym=>tvalue).exists?)
				$alog.lwrite(("Clck on span /:"+tag+"/"+tvalue+"/"), "DEBG")
				$browser.span(tag.to_sym=> tvalue).click

			elsif ($browser.div(tag.to_sym=>tvalue).exists?)
				$alog.lwrite(("Clck on div /:"+tag+"/"+tvalue+"/"), "DEBG")
				$browser.div(tag.to_sym=> tvalue).click

			else
				$pfd.applErr('false', ("Click unknown obj. Tag: /"+ tag+"/ value: /"+tvalue+"/"))
				res= CRITICAL
			end
		end
	rescue
		$pfd.applErr('false', ("Click: cannot find obj: tag /"+ tag+"/ value /"+tvalue+"/"+$!.to_s))
		res= CRITICAL
	end
	return res
end

################################################################################
def selectList( par1, par2)

	if par1=="" || par2==""
		$alog.lwrite(("Select from List: parms missing: /"+par1+"/ or /"+par2+"/"), "DEBG")
		res=CRITICAL
	else
		ftype= []
		ftype= par1.split(/=/, 2)
		tag= ftype[0]
		tvalue= ftype[1]
		ftype= par2.split(/=/, 2)

		begin
			$browser.select_list(tag.to_sym=>tvalue).select(ftype[1])			# single value
			$pfd.applErr('true', "OK: Select list: "+par1+"& value:/"+ftype[1]+"/")
			res=OK
		rescue
			$pfd.applErr('false', "Select list not found: tag /"+par1+"/ value /"+ftype[1]+"/"+$!.to_s)
			res=CRITICAL
		end
	end
	return res
end

################################################################################
def gotoUrl( base, url)

	res=OK
	if !(url=~/http:/)															# if NOT a complete URL
		if (base[-1]==url[0])													# skip double /
			url=url[1..-1]														# cut first char
		end
		url= base+url
	end

	begin
		$pfd.tstart( url)
		$browser.goto( url)
	rescue
		$pfd.applErr('false', ("Cannot reach URL. Parm: /"+url+"/"))
		res=CRITICAL
	end

	return res
end

################################################################################
def verifyElement(par1, par2)

	if par1==""
		par1=par2
	end
	ftype= []
	ftype= par1.split(/=/, 2)
	res=OK
	begin
		if $browser.element(ftype[0].to_sym, ftype[1]).exists?
			$pfd.applErr('true', "OK: element found :"+ftype[0]+" value:/"+ftype[1]+"/")
		else
			$pfd.applErr('false', ("Element not found. Parm: /"+par1+"/"))
		end
	rescue
		$pfd.applErr('false', ("Element not selectable. Parm: /"+par1+"/"))
		res=CRITICAL

	end
	return res
end

################################################################################
def verifyText(type, par1, par2)

	if par1==""
		par1=par2
	end

	res=OK
	begin
		if $browser.text.include? par1
			$pfd.applErr('true', "OK: text found "+type+". value:/"+par1+"/")
		else
			$pfd.applErr('false', "ERR_APPL: text /"+par1+"/ not found at url "+ $browser.url)
		end
	rescue
		$pfd.applErr('false', ("Text not selectable. Parm: /"+par1+"/"))
		res=CRITICAL
	end

	return res																	#  mark error but proceed w/ processing
end

################################################################################


################################################################################
def verifyTitle(type, par1, par2)
# always return OK: execution goes on

	if par1==""
		par1=par2
	end

	res= CRITICAL
	begin

		Watir::Wait.until {
			$browser.title.include? par1
		}
		$pfd.tstop
		$pfd.applErr('true',"OK: title found:/"+par1+"/")
		sleep TIMETICK															# small sleep to let objects appear
		res= OK
	rescue
		$pfd.tstop
		$pfd.applErr('false', ("Title not selectable. Value: "+par1+" "+$!.to_s))
#		 catchHttpErr()															# non implemented yet
		res= CRITICAL
	end

	return res
end

################################################################################
def textType ( par1, par2)
	ftype= []
	ftype= par1.split(/=/, 2)

	res= CRITICAL
	begin
		if $browser.text_field(ftype[0].to_sym, ftype[1]).exist?
			$browser.text_field(ftype[0].to_sym, ftype[1]).clear
			$browser.text_field(ftype[0].to_sym, ftype[1]).set(par2)
			$pfd.applErr('true', "Type on field "+ftype[0]+" name="+ftype[1]+" text/"+par2+"/")
			sleep TIMETICK														# small sleep to let objects appear
			res= OK
		else
			$pfd.applErr('false', "Unknown element "+ftype[1]+" with parms: /"+par1+"/ e /"+par2+"/")
			res= CRITICAL
		end

	rescue
		$pfd.applErr('false', ("Cannot type text. Parm: /"+par1+"/"))
		res=CRITICAL
	end

	return res
end

################################################################################
def pause ( par1, par2)

	if par1==""
		par1=par2
	end
	mytime= par1.to_f/1000														# passed in msec
	if mytime ==0
		$alog.lwrite(("Null value pause from  /"+par1+"/"), "ERR_")				# track obj
	end
	$pfd.tstop																	# stop timer
	sleep mytime
	return OK
end

################################################################################
def dragAndDropBy( par1, par2)

	ftype= []
	ftype= par1.split(/=/, 2)
	coord= []
	coord= par2.split(/,/, 2)

	begin
		el= $browser.element(ftype[0].to_sym, ftype[1])
		$pfd.tstart( $browser.url.to_s+par1)
		el.drag_and_drop_by( coord[0].to_i, coord[1].to_i)
		$pfd.applErr('true', "Drag and drop "+par1+" by "+par2)
		res= OK
	rescue
		$pfd.applErr('false', ("DragAndDrop failed. Values: /"+par1+"/"+par2+"/ "+$!.to_s))
#		catchHttpErr()															# non implemented yet
		res= CRITICAL
	end
	return res
end

################################################################################
#
def waitForElementPresent ( par1, par2)
	ftype= []
	ftype= par1.split(/=/, 2)
	tag= ftype[0]
	tvalue= ftype[1]
	$alog.lwrite(("WaitForElement "+tag+" with value="+tvalue+". Par2=/"+par2+"/"), "DEBG")

	begin
		numTicks= ($gcfd.pageTimeOut/TIMETICK).to_i								# calculate the number of ticks
		numTicks.times do |iTick|
			case tag
			when "link"
				if $browser.link(:text, tvalue).exists?							# check exists
					$pfd.tstop
					$alog.lwrite(("Link with text="+tvalue+" exists"), "DEBG")
					return OK
				end
			when "span"
				if $browser.element(:text, tvalue).exists?						# check exists
					$pfd.tstop
					$alog.lwrite(("Span with text="+tvalue+" exists"), "DEBG")
					return OK
				end
			when "css"
				if $browser.element(:css, tvalue).exists?						# check exists
					$pfd.tstop
					$alog.lwrite(("CSS with text="+tvalue+" exists"), "DEBG")
					return OK
				end
			when "id"
				if $browser.element(:id, tvalue).exists?						# check exists
					$pfd.tstop
					$alog.lwrite(("Element with id="+tvalue+" exists"), "DEBG")
					return OK
				end
			when "name"
				if $browser.button(:name, tvalue).exists?						# check exists
					$pfd.tstop
					$alog.lwrite(("Button with name="+tvalue+" exists"), "DEBG")
					return OK
				elsif 
					$browser.select_list(:name, tvalue).exists?					# check exists
					$pfd.tstop
					$alog.lwrite(("Element with name="+tvalue+" exists"), "DEBG")
					return OK
				end
			else
				$pfd.applErr('false',("CANnot manage element "+tag+" with value "+tvalue))
				return CRITICAL
			end
			sleep TIMETICK
		end
		$pfd.applErr(" on WaitForElement "+tag+" with value="+tvalue)
		return CRITICAL

	rescue
		$pfd.applErr('false', ("CANnot find "+tag+ " with value "+tvalue+": exception:"+$!.to_s)) # if found return immediately
		return CRITICAL
	end

end

################################################################################
#
def waitForTextPresent ( par1, par2)

	numTicks= ($gcfd.pageTimeOut/TIMETICK).to_i									# calculate the number of ticks
	numTicks.times do |iTick|
		if $browser.text.include? par1
			$alog.lwrite(("Text "+par1+" exists"), "DEBG")
			$pfd.tstop
			return OK															# if found return immediately
		end
		sleep TIMETICK
	end

	$pfd.applErr('false', ("CANnot find text "+par1))
	return CRITICAL

end

################################################################################
#
def waitForTitle ( par1, par2)

	numTicks= ($gcfd.pageTimeOut/TIMETICK).to_i									# calculate the number of ticks
	numTicks.times do |iTick|
		if $browser.title.include? par1
			$alog.lwrite(("Title "+par1+" exists"), "DEBG")
			$pfd.tstop
			return OK															# if found return immediately
		end
		sleep TIMETICK
	end

	$pfd.applErr('false', ("CANnot find title "+par1))
	return CRITICAL

end

################################################################################
#
def radioset ( par1, par2)
	ftype= []
	ftype= par1.split(/=/, 2)

	$alog.lwrite(("Custom1 on "+ftype[0]+" name="+ftype[1]+" text/"+par2+"/"), "DEBG")
	$browser.radio(ftype[0].to_sym, ftype[1]).set

end


################################################################################
#
#	  watir command line recall
#
################################################################################
def processElement (urlBase, webCmd, par1, par2)
#
# return res != OK will abort the intire table!!
# to be used only when needed
#
	$alog.lwrite(("Cmnd "+webCmd+" Parms:/"+par1+"/"+par2+"/"), "DEBG")

	case webCmd.downcase
		when "open"
			res= gotoUrl(urlBase, par1)
		when "type"
			res= textType(par1, par2)
		when "click", "clickat", "clickandwait"
			res= click( par1)
		when "assertelementpresent", "verifyelementpresent"
			res= verifyElement(par1, par2)
		when "asserttitle", "verifytitle"
			res= verifyTitle(":title", par1, par2)
		when "asserttextpresent", "verifytextpresent"
			res= verifyText(":text", par1, par2)
		when "select"
			res= selectList(par1, par2)
		when "pause"
			res= pause(par1, par2)
		when "draganddrop"
			res= dragAndDropBy(par1, par2)
		when "waitforelementpresent"
			res= waitForElementPresent(par1, par2)
		when "waitfortextpresent"
		when "waitfortext"
			res= waitForTextPresent(par1, par2)

#		when "radioset"
#			radioset(par1, par2)

		when "assertalert", "mousedownat"
			$pfd.applErr('false', "NOT_ implemented yet: "+webCmd+" Parms:/"+par1+"/"+par2+"/")
			res= OK
		else
			$pfd.applErr('false', "UNKN command "+webCmd+" Parms:/"+par1+"/"+par2+"/")
			res= OK
	end
	return res
end
