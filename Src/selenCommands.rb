################################################################################
#
#	Nagios Ruby WebDriver plugin.
#	Watir single commands functions
#
################################################################################
#
def click( par1 )																# need do act differently
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

	res= $brws.click(tag.to_sym, tvalue)
	return res
end

################################################################################
def selectList( par1, par2)

	if par1=="" || par2==""
		$alog.lwrite(("Select from List: parms missing: /"+par1+"/ or /"+par2+"/"), "DEBG")
		return CRITICAL
	end
	ftype= []
	ftype= par1.split(/=/, 2)
	tag= ftype[0].to_sym
	tvalue= ftype[1]
	ftype= par2.split(/=/, 2)

	res= $brws.selectList(tag, tvalue, [ftype[1]])
	return res
end

################################################################################
def gotoUrl( base, url)

	res=OK
	if !(url=~/https?:/)														# if NOT a complete URL ()
		if(base[-1]==url[0])													# skip double /
			url=url[1..-1]														# cut first char
		end
		url= base+url
	end

	res= $brws.goto( url)
	return res
end

################################################################################
def verifyElement(par1, par2)

	if par1==""
		par1=par2
	end
	ftype= []
	ftype= par1.split(/=/, 2)
	tag= ftype[0].to_sym
	tvalue= ftype[1]

	res= $brws.lookFor( tag, tvalue, false)
	return res
end

################################################################################
def verifyText(type, par1, par2)

	if par1==""
		par1=par2
	end

	res= $brws.lookFor(:text, par1, false)
	return res
end

################################################################################
def verifyTitle(type, par1, par2)

	if par1==""
		par1=par2
	end

	res= $brws.lookFor(:title, par1, false)
	return res

end
################################################################################
def waitForElementPresent( par1, par2)
	ftype= []
	ftype= par1.split(/=/, 2)
	tag= ftype[0].to_sym
	tvalue= ftype[1]
	res= $brws.lookFor(tag, tvalue, true)
	return res

end

################################################################################
def waitForTextPresent( par1, par2)

	if par1==""
		par1=par2
	end
	res= $brws.lookFor(:text, par1, true)
	return res

end

################################################################################
def waitForTitle( par1, par2)

	if par1==""
		par1=par2
	end
	res= $brws.lookFor(:title, par1, true)
	return res

end

################################################################################
#
def radioset( par1, par2)
	ftype= []
	ftype= par1.split(/=/, 2)
	tag= ftype[0].to_sym
	tvalue= ftype[1]

	res= $brws.radioSet(tag, tvalue)
	return res
#	$browser.radio(ftype[0].to_sym, ftype[1]).set

end

################################################################################
def textType( par1, par2)

	a, tvalue= par1.split(/=/, 2)
	res= $brws.typeText(a.to_sym, tvalue, par2)
	return res

end

################################################################################
def pause( par1, par2)

	$pfd.tstop("")																	# stop timer
	if par1==""
		par1=par2
	end
	mytime= par1.to_f/1000														# passed in msec
	if mytime ==0
		$alog.lwrite(("Null value pause from  /"+par1+"/"), "ERR_")				# track obj
	else
		$alog.lwrite(("paused for "+par1+" ms."), "DEBG")					# track obj
	end
	sleep mytime
	return OK
end

################################################################################
def dragAndDropBy( par1, par2)

	ftype= []
	ftype= par1.split(/=/, 2)
	coord= []
	coord= par2.split(/,/, 2)

	$brws.dragAndDrop(ftype[0].to_sym, ftype[1], coord[0].to_i, coord[1].to_i)
	return res
end


################################################################################
#
#	  watir command line recall
#
################################################################################
def processElement( urlBase, webCmd, par1, par2)
#
# return res != OK will abort the intire table!!
# to be used only when needed
#
	$alog.lwrite(("Cmnd "+webCmd+" Parms:/"+par1+"/"+par2+"/"), "DEBG")

	case webCmd.downcase
	when "open"									then res= gotoUrl(urlBase, par1)
	when "type"									then res= textType(par1, par2)
	when "click", "clickat", "clickandwait"		then res= click( par1)
	when "assertelementpresent", "verifyelementpresent" then res= verifyElement(par1, par2)
	when "asserttitle", "verifytitle"			then res= verifyTitle(":title", par1, par2)
	when "asserttextpresent", "verifytextpresent" then res= verifyText(":text", par1, par2)
	when "select"								then res= selectList(par1, par2)
	when "pause"								then res= pause(par1, par2)
	when "draganddrop"							then res= dragAndDropBy(par1, par2)
	when "waitforelementpresent"				then res= waitForElementPresent(par1, par2)
	when "waitfortitle"							then res= waitForTitle(par1, par2)
	when "waitfortextpresent", "waitfortext"	then res= waitForTextPresent( par1, par2)

#  	when "radioset"								radioset(par1, par2)
	when "assertalert", "mousedownat"			then 
			$pfd.applRes(false, "NOT_ implemented yet: "+webCmd+" Parms:/"+par1+"/"+par2+"/", "")
			res= OK
	else
			$pfd.applRes(false, "UNKN command "+webCmd+" Parms:/"+par1+"/"+par2+"/", "")
			res= OK
	end
	return res
end



################################################################################
#
#  Operation table management
#	receives the file name "fconfig" parameter
#	load table data
#
################################################################################
#

def processOpTable( optable)

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

	elemNum=(i/3)
	0.upto(elemNum-1) {|j|														# pass each command line
		rcode= processElement( urlBase, cmds[j*3], cmds[j*3+1], cmds [(j*3)+2])
		if rcode != OK then														# if OK proceed with processing
			$alog.lwrite("Command table "+ optable+ " aborted on step "+cmds[j*3], "ERR_")
			return rcode
		end
	}

	$alog.lwrite("Command table "+ optable+ " finished ", "INFO")
	return OK

end

