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


public any function printToConnectedPrinter
(
	required string uncPath,
	string zpl = ""
)
{
	var zplBatchAbsoluteFilePath = _createBatchFile();
	var zplDataAbsoluteFilePath = _writeToZplFile( arguments.zpl );

	var exeArgs = [];
	var errorMsg = "";

	try {

		exeArgs[1] = arguments.uncPath;
		exeArgs[2] = zplDataAbsoluteFilePath;

		execute {
			variable="batchScriptOutput",
			name="#LOCAL.zplBatchAbsoluteFilePath#",
			arguments="#LOCAL.aArguments#",
			timeout="15",
			errorVariable="batchScriptError",
		}

		if ( len( batchScriptError ) )
			errorMsg = batchScriptError;

		catch {
			rethrow();
		}
	}

	return errorMsg;
}
</cfscript>


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