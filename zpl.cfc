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
	<cfargument name="uncPath" type="string" required="false" default="" />
	<cfargument name="zpldata" type="string" required="true" default="" />
	
	<cfset var LOCAL = structNew() />
	
	<cfset LOCAL.aArguments = arrayNew(1) />
	<cfset LOCAL.zplDataAbsoluteFilePath = "" />
	<cfset LOCAL.zplBatchAbsoluteFilePath = "" />
	<cfset LOCAL.errorMsg = "" />
	
	<cfset LOCAL.zplBatchAbsoluteFilePath = _createBatchFile() />
	
	<cfset LOCAL.zplDataAbsoluteFilePath = _writeToZplFile( ARGUMENTS.zpldata ) />
	
	<cftry>
		
		<cfset LOCAL.aArguments[1] = "#ARGUMENTS.uncPath#" />
		<cfset LOCAL.aArguments[2] = "#LOCAL.zplDataAbsoluteFilePath#" />
		
		<cfexecute variable="batchScriptOutput"
			name="#LOCAL.zplBatchAbsoluteFilePath#"
			arguments="#LOCAL.aArguments#"
			timeout="15"
			errorVariable="batchScriptError"
			/>
		
		<cfif len( batchScriptError )>
			<cfset LOCAL.errorMsg = batchScriptError />
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
	
	<cfreturn LOCAL.errorMsg />
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


</cfcomponent>