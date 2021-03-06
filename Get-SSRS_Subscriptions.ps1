<#
.SYNOPSIS
    Lists SSRS Report Subscriptions for One report
	
.DESCRIPTION
    Lists SSRS Report Subscriptions for One report
   
.EXAMPLE
    
	
.Inputs
    

.Outputs
	

.NOTES
    https://msdn.microsoft.com/en-us/library/ms154020(v=sql.130).aspx

    1) The ExtensionSettings holds the Subscription Type settings(case sensitive):

    a) "Report Server Email"
        Parameters:
        TO
        CC
        BCC
        ReplyTo
        IncludeReport = True/False
        RenderFormat = EXCELOPENXML, IMAGE, XML, PPTX, CSV, PDF (Landscape), PDF, MHTML, WORDOPENXML, PDF (Portrait)
        Priority = NORMAL, HIGH
        Subject = @ReportName
        Comment
        IncludeLink = True/False

            
    b) "Report Server Fileshare"
        Parameters:
        FILENAME = "report.pdf"
        PATH = "\\fileserver\mnt\subfolder"
        RENDER_FORMAT = PDF, MHTML, IMAGE, CSV, XML, EXCELOPENXML, PDF (Landscape), PPTX, WORDOPENXML, PDF (Portrait)
        WRITEMODE = None, OverWrite, AutoIncrement
        FILEEXTN = True/False - Add an Extension based on Type (.PDF)
        USERNAME = Share Creds
        PASSWORD = Share Creds
        DEFAULTCREDENTIALS
    
    
    2) The MatchData or Schedule XML:
    https://msdn.microsoft.com/en-us/library/reportservice2005.recurrencepattern(v=sql.130).aspx

    Monthly (Calendar Days of Selected Months):
    <ScheduleDefinition>
		<StartDateTime>2017-01-01T07:00:00.000-05:00</StartDateTime>
            <MonthlyRecurrence>
                <Days>1</Days>
                <MonthsOfYear>
                    <January>true</January>
                    <February>true</February>
                    <March>true</March>
                    <April>true</April>
                    <May>true</May>
                    <June>true</June>
                    <July>true</July>
                    <August>true</August>
                    <September>true</September>
                    <October>true</October>
                    <November>true</November>
                    <December>true</December>
                </MonthsOfYear>
            </MonthlyRecurrence>
    <ScheduleDefinition>

    Weekly (M-F at 0700):
    <ScheduleDefinition>
		<StartDateTime>2017-01-01T07:00:00.000-05:00</StartDateTime>
		<WeeklyRecurrence>
			<WeeksInterval>1</WeeksInterval>
				<DaysOfWeek>
					<Monday>true</Monday>
					<Tuesday>true</Tuesday>
					<Wednesday>true</Wednesday>
					<Thursday>true</Thursday>
					<Friday>true</Friday>
				</DaysOfWeek>
		</WeeklyRecurrence>
	</ScheduleDefinition>

    Daily (at 0600):
    <ScheduleDefinition>
	    <StartDateTime>2017-01-01T06:00:00.000-05:00</StartDateTime>
        <DailyRecurrence>
            <DaysInterval>1</DaysInterval>
        </DailyRecurrence>
    </ScheduleDefinition>

    Once (at 1025):
    <ScheduleDefinition>
        <StartDateTime>02/20/2017 10:25:00</StartDateTime>
    </ScheduleDefinition>

#>


Param(
    [parameter(Position=0,mandatory=$true,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$SQLInstance,
    [parameter(Position=1,mandatory=$true,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$Report
)

function Format-Xml {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$Text
    )

    begin {
        $data = New-Object System.Collections.ArrayList
    }
    process {
        [void] $data.Add($Text -join "`n")
    }
    end {
        $doc=New-Object System.Xml.XmlDataDocument
        $doc.LoadXml($data -join "`n")
        $sw=New-Object System.Io.Stringwriter
        $writer=New-Object System.Xml.XmlTextWriter($sw)
        $writer.Formatting = [System.Xml.Formatting]::Indented
        $doc.WriteContentTo($writer)
        $sw.ToString()
    }
}
#Export-ModuleMember -Function Format-Xml


$ReportServerUri  = "http://$SQLInstance/ReportServer/ReportService2010.asmx"

# Optional -class parameter? 
$rs2010 += New-WebServiceProxy -Uri $ReportServerUri -UseDefaultCredential;  

# Get Types from Namespace
$type = $rs2010.GetType().Namespace

# Define Object Types for Subscription property call
# http://stackoverflow.com/questions/25984874/not-able-to-create-objects-in-powershell-for-invoking-a-web-service
# http://stackoverflow.com/questions/32611187/using-complex-objects-via-a-web-service-from-powershell

$ExtensionSettingsDataType = ($type + '.ExtensionSettings')
$ActiveStateDataType = ($type + '.ActiveState')
$ParmValueDataType = ($type + '.ParameterValue')

# Create typed parameters the method needs
$extSettings = New-Object ($ExtensionSettingsDataType)
$paramSettings = New-Object ($ParmValueDataType)
$activeSettings = New-Object ($ActiveStateDataType)
$desc = ""
$status = ""
$eventType = ""
$matchdata = ""


# Call the WebService
try
{
    $subscriptions = $rs2010.ListSubscriptions($report)
    if ($subscriptions -ne $null)
    {
        Write-Output("Subscriptions for Report {0} `r`n" -f $report)

        # Show Subs
        foreach($sub in $subscriptions)
        {
            # Sub
            Write-Output("== Subscription {0} ==" -f $subscriptions.IndexOf($sub)++)

            # Sub Configs
            Write-Output("`r`nSubscription Configs:")
            Write-Output("------------------------------")
            $Subproperty = $rs2010.GetSubscriptionProperties($sub.subscriptionID, [ref]$extSettings, [ref]$desc, [ref]$activeSettings, [ref]$status, [ref]$eventType, [ref]$matchData, [ref]$paramSettings)
            Write-Output("Name: {0}" -f $desc)
            Write-Output("Owner: {0}" -f $Subproperty)
            Write-Output("Status: {0}" -f $status)
            Write-Output("EventType: {0}" -f $eventType)
            Write-Output("Subscription Type: {0}" -f $extSettings.Extension)
            Write-Output("XML Schedule:")
            Format-XML ($matchdata)
            

            # Report Type Configs
            if ($extSettings.ParameterValues -ne $null)
            {
                Write-Output("`r`nExtension Settings:")
                Write-Output("------------------------------")
                foreach($extSetting in $extSettings.ParameterValues)
                {
                    Write-Output("{0}={1}" -f $extSetting.Name, $extSetting.Value)
                }

            }

            # Report Parameters
            if ($paramSettings -ne $null)
            {
                Write-Output("`r`nReport Parameters:")
                Write-Output("------------------------------")
                
                foreach($ReportParameter in $paramSettings)
                {
                  
                    Write-Output("{0} {1}" -f $ReportParameter.name, $ReportParameter.Value)
                }

            }


            # Active Settings
            if ($activeSettings -ne $null)
            {
                Write-Output("`r`nActive Settings:")
                Write-Output("------------------------------")
                foreach($activesetting in $activeSettings)
                {
                    Write-Output("DeliveryExtensionRemoved: {0}" -f $activesetting.DeliveryExtensionRemoved)
                    Write-Output("DeliveryExtensionRemovedSpecified: {0}" -f $activesetting.DeliveryExtensionRemovedSpecified)
                    Write-Output("DisabledByUserSpecified: {0}" -f $activesetting.DisabledByUserSpecified)
                    Write-Output("InvalidParameterValue: {0}" -f $activesetting.InvalidParameterValue)
                    Write-Output("InvalidParameterValueSpecified: {0}" -f $activesetting.InvalidParameterValueSpecified)
                    Write-Output("MissingParameterValue: {0}" -f $activesetting.MissingParameterValue)
                    Write-Output("MissingParameterValueSpecified: {0}" -f $activesetting.MissingParameterValueSpecified)
                    Write-Output("SharedDataSourceRemoved: {0}" -f $activesetting.SharedDataSourceRemoved)
                    Write-Output("SharedDataSourceRemovedSpecified: {0}" -f $activesetting.SharedDataSourceRemovedSpecified)
                    Write-Output("UnknownReportParameter: {0}" -f $activesetting.UnknownReportParameter)
                    Write-Output("UnknownReportParameterSpecified: {0}" -f $activesetting.UnknownReportParameterSpecified)
                }

            }

            Write-Output("`r`n")
        }
    }
}
catch
{
    Write-Output ("Exception: {0} Inner: {1}" -f $_.Exception.Message, $_.Exception.Message.InnerException)
    $error[0] | fl -force
}



$rs2010 = $null
