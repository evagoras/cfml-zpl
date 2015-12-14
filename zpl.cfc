<cfcomponent output="false">


<cfscript>
public any function printToNetworkPrinter
(
	required string ip,
	required numeric port,
	string zpl=""
)
{
	// open and init java socket connection
	var sock = createObject( "java", "java.net.Socket" );
	sock.init( arguments.ip, arguments.port );

	// socket is open and ready to receive
	var connected = sock.isConnected();

	if ( connected ) {
		// create an output stream buffer for writing out the ZPL
		var streamOut = sock.getOutputStream();
		var output = createObject("java", "java.io.DataOutputStream").init( streamOut );
		streamOut.flush();
		// send the ZPL by writing to the output buffer
		output.writeBytes( arguments.zpl );
		streamOut.flush();
	}

	// close down and clean up the socket connection
	sock.shutdownOutput();
	sock.close();

	return connected;
}
</cfscript>


<cffunction name="printToConnectedPrinter" access="public" returntype="any" output="false">
	<cfargument name="zpldata" type="string" required="true" default="" />
	<cfargument name="printer_id" type="string" required="false" default="" />
	<cfargument name="printer_unc_path" type="string" required="false" default="" />
	
	<cfset var LOCAL = structNew() />
	
	<cfset LOCAL.aArguments = arrayNew(1) />
	<cfset LOCAL.qPrinterInfo = queryNew("") />
	<cfset LOCAL.cZplDataAbsoluteFilePath = "" />
	<cfset LOCAL.cZplBatchAbsoluteFilePath = "" />
	<cfset LOCAL.cError = "" />
	
	<cfif len( ARGUMENTS.printer_unc_path )>
		<cfset LOCAL.qPrinterInfo = GetDetails( printer_unc_path = "#ARGUMENTS.printer_unc_path#" ) />
	<cfelseif len( ARGUMENTS.printer_id )>
		<cfset LOCAL.qPrinterInfo = GetDetails( printer_id = "#ARGUMENTS.printer_id#" ) />
	<cfelse>
		<cfset LOCAL.qPrinterInfo = GetDefault() />
	</cfif>
	
	<cfset LOCAL.cZplBatchAbsoluteFilePath = _createBatchFile() />
	
	<<cfset LOCAL.cZplDataAbsoluteFilePath = _writeToZplFile( ARGUMENTS.zpldata ) />
	
	<cftry>
		
		<cfset LOCAL.aArguments[1] = "#LOCAL.qPrinterInfo.printer_unc_path#" />
		<cfset LOCAL.aArguments[2] = "#LOCAL.cZplDataAbsoluteFilePath#" />
		
		<cfexecute variable="batchScriptOutput"
			name="#LOCAL.cZplBatchAbsoluteFilePath#"
			arguments="#LOCAL.aArguments#"
			timeout="15"
			<!--- errorVariable="batchScriptError" --->
			/>
		
		<cfif len( batchScriptError )>
			<cfset LOCAL.cError = batchScriptError />
		</cfif>
		
		<!---
		<cfoutput>
			SCRIPT OUTPUT:<br />
			<cfdump var="#batchScriptOutput#" labl="Script Output" /><br />
			ERRORS:<br />
			<cfdump var="#batchScriptError#" labl="Errors" />
		</cfoutput>
		--->
		
		<cfcatch>                
			<cfrethrow />        
		</cfcatch>
		
	</cftry>
	
	<cfreturn LOCAL.cError />
</cffunction>


<cffunction name="GetDetails" access="public" returntype="query" output="false">
	<cfargument name="printer_id" type="string" required="false" default="" />
	<cfargument name="printer_name" type="string" required="false" default="" />
	<cfargument name="printer_unc_path" type="string" required="false" default="" />
	
	<cfset var qResults = queryNew("") />
	
	<cfquery name="qResults">
		SELECT * 
		FROM dbo.printers WITH(NOLOCK) 
		WHERE 
			1 = 1 
			<cfif len( ARGUMENTS.printer_id )>
				AND id = <cfqueryparam cfsqltype="cf_sql_integer" value="#ARGUMENTS.printer_id#" /> 
			<cfelse>
				AND isDefault = <cfqueryparam cfsqltype="cf_sql_bit" value="1" /> 
			</cfif>
			<cfif len( ARGUMENTS.printer_name )>
				AND printer_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#ARGUMENTS.printer_name#" /> 
			</cfif>
			<cfif len( ARGUMENTS.printer_unc_path )>
				AND printer_unc_path = <cfqueryparam cfsqltype="cf_sql_varchar" value="#ARGUMENTS.printer_unc_path#" /> 
			</cfif>
	</cfquery>
	
	<cfreturn qResults />
</cffunction>


<cffunction name="GetDefault" access="public" returntype="query" output="false">
	<cfset var qResults = queryNew("") />
	
	<cfset qResults = GetDetails(
		is_default = true
		) />
	
	<cfreturn qResults />
</cffunction>


<cffunction name="_writeToZplFile" access="private" returntype="string" output="false">
	<cfargument name="zpldata" type="string" required="true" />
	
	<cfset var LOCAL = structNew() />
	
	<cfset LOCAL.cAbsoluteFilePath = expandPath( "/print-zpl.txt" ) />

	<cflock timeout="15" scope="request" type="exclusive">
		<cffile action="write" file="#LOCAL.cAbsoluteFilePath#" output="#ARGUMENTS.zpldata#" />
	</cflock>
	
	<cfreturn LOCAL.cAbsoluteFilePath />
</cffunction>


<cffunction name="_createBatchFile" access="private" returntype="string" output="false">
	<cfset var LOCAL = structNew() />
	
	<cfset LOCAL.bFileExists = false />
	<cfset LOCAL.cAbsoluteFilePath = expandPath( "/print-zpl.bat" ) />
	<cfset LOCAL.cFileContents = "" />
	
	<cfif fileExists( LOCAL.cAbsoluteFilePath )>
		<cfset LOCAL.bFileExists = true />
	</cfif>
	
	<cfif NOT LOCAL.bFileExists>
		
		<cfsavecontent variable="LOCAL.cFileContents"><cfoutput>net use lpt1: %1#chr(13) & chr(10)#
copy %2 lpt1#chr(13) & chr(10)#
net use lpt1: /d</cfoutput></cfsavecontent>

		<cflock timeout="15" scope="request" type="exclusive">
			<cffile action="write" file="#LOCAL.cAbsoluteFilePath#" output="#LOCAL.cFileContents#" />
		</cflock>
		
	</cfif>
	
	<cfreturn LOCAL.cAbsoluteFilePath />
</cffunction>


<cffunction name="PrintRestockingLabel" access="private" output="false" returntype="string">
	<cfargument name="stockcode" type="string" required="true" />
	<cfargument name="bin" type="string" required="true" />
	<cfargument name="quantity" type="string" required="false" default="1" />
	<cfargument name="printerID" type="string" required="false" default="4" />

	<cfset var loc = {} />

	<cfsavecontent variable="loc.zplData">
		<cfoutput>
		<!--- start of label format --->
		^XA

		<!--- label home position --->
		^LH0,0

		<!--- label length --->
		^LL1600

		<!--- STOCKCODE header --->
		^FO52,70 ^A0N,36 ^FDSTOCKCODE ^FS
		<!--- underline --->
		^FO42,110 ^GB748,0,2 ^FS
		<!--- barcode --->
		^FO52,160 ^BY1,1.0 ^B3N,,200,N ^FD#trim(ARGUMENTS.stockcode)# ^FS
		<!--- actual stockcode --->
		^FO52,380 ^A0N,36 ^FB728,2 ^FD#trim(ARGUMENTS.stockcode)# ^FS

		<!--- BIN header --->
		^FO52,550 ^A0N,36 ^FDBIN ^FS
		<!--- underline --->
		^FO42,590 ^GB748,0,2 ^FS
		<!--- barcode --->
		^FO52,640 ^BY1,1.0 ^B3N,,200,N ^FD#trim(ARGUMENTS.bin)# ^FS
		<!--- actual bin --->
		^FO52,860 ^A0N,36 ^FD#trim(ARGUMENTS.bin)# ^FS

		<!--- print quantity --->
		^PQ#ARGUMENTS.quantity#

		<!--- print rate per second --->
		^PR6

		<!--- end of label format --->
		^XZ
		</cfoutput>
	</cfsavecontent>

	<cfset loc.result = SendToLabelPrinter(
		printerID = ARGUMENTS.printerID,
		zplData = loc.zplData
		) />

	<cfreturn loc.result />
</cffunction>


</cfcomponent>