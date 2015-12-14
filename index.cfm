<p>This is an example of how to print some ZPL data to a network as well as to a compuer-connected label printer.</p>

<cfsavecontent variable="zplData">
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


<cfset zpl = createObject("component", "zpl") />

<cfset networkResult = zpl.printToNetworkPrinter(
    ip = "192.168.1.5680"
    port = "80",
    zpl = zplData
    ) />
<cfdump var="#networkResult#" label="network printer result" />


<cfset connectedResult = zpl.printToConnectedPrinter(
    unc_path = "\\dellpc\labelprinter"
    zpl = zplData
    ) />
<cfdump var="#connectedResult#" label="connected printer result" />
