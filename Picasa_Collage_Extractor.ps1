<#
.SYNOPSIS
    Extracts individual visible images from rendered Google Picasa collages.

.DESCRIPTION
    Uses Picasa .CXF collage definitions together with the final rendered
    collage image to crop the visible image tiles back into separate files.

    The script supports two modes:

    BATCH MODE
    ----------
    If "list_of_cxf_files.txt" exists in the same folder as this script,
    the script automatically reads all CXF paths from that file and processes
    them one by one.

    For each CXF file, the script looks for a matching rendered collage using
    the same basename and one of these extensions, in this order:

        .jpg
        .jpeg
        .png

    Example:

        2006-12-03_Tomtecupen.cxf
        2006-12-03_Tomtecupen.jpg

    INTERACTIVE MODE
    ----------------
    If "list_of_cxf_files.txt" does NOT exist, the script prompts for one
    finished collage image and automatically looks for a matching CXF file.

    IMPORTANT
    ---------
    This does NOT recover the original photographs.

    It extracts the visible portions from the final rendered collage.

    Any image area that Picasa cropped away, covered, rotated out of view,
    or otherwise did not render into the collage cannot be recovered.

.NOTES
    Version : 2.1

    Safe operation:
      - Original collage images are not modified.
      - CXF files are not modified.
      - Extracted files are written to separate folders.

    Current limitations:
      - Rotated nodes (theta != 0) are skipped.
      - Designed primarily for Picasa "picturegrid" collages.
#>


# ===========================================================================
# Configuration
# ===========================================================================

$ListFile = Join-Path $PSScriptRoot 'list_of_cxf_files.txt'

$SupportedCollageExtensions = @(
    '.jpg',
    '.jpeg',
    '.png'
)

$JpegQuality = 95


# ===========================================================================
# Functions
# ===========================================================================


function Get-CleanPath {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return $Path.Trim().Trim('"').Trim("'")
}


function Get-MatchingCollageImage {

    param (
        [Parameter(Mandatory = $true)]
        [string]$CxfPath
    )

    foreach ($Extension in $SupportedCollageExtensions) {

        $Candidate = [System.IO.Path]::ChangeExtension(
            $CxfPath,
            $Extension
        )

        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            return $Candidate
        }
    }

    return $null
}


function Get-TrimmedRectangle {

    param (
        [Parameter(Mandatory = $true)]
        [System.Drawing.Bitmap]$Bitmap,

        [Parameter(Mandatory = $true)]
        [System.Drawing.Rectangle]$Rectangle,

        [int]$WhiteThreshold = 245,

        [double]$RequiredWhiteRatio = 0.95,

        [int]$MaximumTrimPixels = 30
    )


    $Left   = $Rectangle.Left
    $Top    = $Rectangle.Top
    $Right  = $Rectangle.Right - 1
    $Bottom = $Rectangle.Bottom - 1


    # -----------------------------------------------------------------------
    # Helper: vertical line mostly white?
    # -----------------------------------------------------------------------

    $IsVerticalLineWhite = {

        param (
            [int]$X,
            [int]$StartY,
            [int]$EndY
        )

        $Total = 0
        $White = 0

        $Length = $EndY - $StartY + 1
        $Step = [Math]::Max(
            1,
            [Math]::Floor($Length / 300)
        )


        for ($Y = $StartY; $Y -le $EndY; $Y += $Step) {

            $Pixel = $Bitmap.GetPixel($X, $Y)

            $Total++

            if (
                $Pixel.R -ge $WhiteThreshold -and
                $Pixel.G -ge $WhiteThreshold -and
                $Pixel.B -ge $WhiteThreshold
            ) {
                $White++
            }
        }


        if ($Total -eq 0) {
            return $false
        }

        return (($White / $Total) -ge $RequiredWhiteRatio)
    }


    # -----------------------------------------------------------------------
    # Helper: horizontal line mostly white?
    # -----------------------------------------------------------------------

    $IsHorizontalLineWhite = {

        param (
            [int]$Y,
            [int]$StartX,
            [int]$EndX
        )

        $Total = 0
        $White = 0

        $Length = $EndX - $StartX + 1
        $Step = [Math]::Max(
            1,
            [Math]::Floor($Length / 300)
        )


        for ($X = $StartX; $X -le $EndX; $X += $Step) {

            $Pixel = $Bitmap.GetPixel($X, $Y)

            $Total++

            if (
                $Pixel.R -ge $WhiteThreshold -and
                $Pixel.G -ge $WhiteThreshold -and
                $Pixel.B -ge $WhiteThreshold
            ) {
                $White++
            }
        }


        if ($Total -eq 0) {
            return $false
        }

        return (($White / $Total) -ge $RequiredWhiteRatio)
    }


    # -----------------------------------------------------------------------
    # Trim left
    # -----------------------------------------------------------------------

    $Trimmed = 0

    while (
        $Left -lt $Right -and
        $Trimmed -lt $MaximumTrimPixels
    ) {

        $IsWhite = & $IsVerticalLineWhite `
            $Left `
            $Top `
            $Bottom

        if (-not $IsWhite) {
            break
        }

        $Left++
        $Trimmed++
    }


    # -----------------------------------------------------------------------
    # Trim right
    # -----------------------------------------------------------------------

    $Trimmed = 0

    while (
        $Right -gt $Left -and
        $Trimmed -lt $MaximumTrimPixels
    ) {

        $IsWhite = & $IsVerticalLineWhite `
            $Right `
            $Top `
            $Bottom

        if (-not $IsWhite) {
            break
        }

        $Right--
        $Trimmed++
    }


    # -----------------------------------------------------------------------
    # Trim top
    # -----------------------------------------------------------------------

    $Trimmed = 0

    while (
        $Top -lt $Bottom -and
        $Trimmed -lt $MaximumTrimPixels
    ) {

        $IsWhite = & $IsHorizontalLineWhite `
            $Top `
            $Left `
            $Right

        if (-not $IsWhite) {
            break
        }

        $Top++
        $Trimmed++
    }


    # -----------------------------------------------------------------------
    # Trim bottom
    # -----------------------------------------------------------------------

    $Trimmed = 0

    while (
        $Bottom -gt $Top -and
        $Trimmed -lt $MaximumTrimPixels
    ) {

        $IsWhite = & $IsHorizontalLineWhite `
            $Bottom `
            $Left `
            $Right

        if (-not $IsWhite) {
            break
        }

        $Bottom--
        $Trimmed++
    }


    $Width  = $Right - $Left + 1
    $Height = $Bottom - $Top + 1


    if ($Width -lt 1 -or $Height -lt 1) {
        return $Rectangle
    }


    return New-Object System.Drawing.Rectangle(
        $Left,
        $Top,
        $Width,
        $Height
    )
}


function Save-Jpeg {

    param (
        [Parameter(Mandatory = $true)]
        [System.Drawing.Bitmap]$Bitmap,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [int]$Quality = 95
    )


    $JpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object {
            $_.MimeType -eq 'image/jpeg'
        } |
        Select-Object -First 1


    if (-not $JpegCodec) {
        throw "Could not locate the Windows JPEG encoder."
    }


    $Encoder = [System.Drawing.Imaging.Encoder]::Quality

    $EncoderParameters =
        New-Object System.Drawing.Imaging.EncoderParameters(1)

    $EncoderParameters.Param[0] =
        New-Object System.Drawing.Imaging.EncoderParameter(
            $Encoder,
            [long]$Quality
        )


    try {

        $Bitmap.Save(
            $Path,
            $JpegCodec,
            $EncoderParameters
        )
    }
    finally {

        $EncoderParameters.Dispose()
    }
}


function Invoke-PicasaCollageExtraction {

    param (
        [Parameter(Mandatory = $true)]
        [string]$CxfPath,

        [Parameter(Mandatory = $true)]
        [string]$CollagePath
    )


    # -----------------------------------------------------------------------
    # Result object
    # -----------------------------------------------------------------------

    $Result = [PSCustomObject]@{
    Success                = $false
    CxfPath                = $CxfPath
    CollagePath            = $CollagePath
    Extracted              = 0
    ExistingOutputsSkipped = 0
    RotatedNodesSkipped    = 0
    RotatedNodes           = @()
    FailedNodes            = 0
    OutputFolder           = $null
    ErrorMessage           = $null
}


    # -----------------------------------------------------------------------
    # Read CXF
    # -----------------------------------------------------------------------

    try {

        [xml]$CxfXml = [System.IO.File]::ReadAllText(
            $CxfPath,
            [System.Text.Encoding]::UTF8
        )
    }
    catch {

        $Result.ErrorMessage =
            "Could not read CXF: $($_.Exception.Message)"

        return $Result
    }


    if (-not $CxfXml.collage) {

        $Result.ErrorMessage =
            "File does not appear to be a valid Picasa CXF."

        return $Result
    }


    $Theme       = [string]$CxfXml.collage.theme
    $Orientation = [string]$CxfXml.collage.orientation
    $Spacing     = [string]$CxfXml.collage.spacing.value

    $Nodes = @($CxfXml.collage.node)


    if ($Nodes.Count -eq 0) {

        $Result.ErrorMessage =
            "No image nodes found in CXF."

        return $Result
    }


    # -----------------------------------------------------------------------
    # Build output folder
    # -----------------------------------------------------------------------

    $CollageDirectory =
        [System.IO.Path]::GetDirectoryName($CollagePath)

    $CollageBaseName =
        [System.IO.Path]::GetFileNameWithoutExtension($CollagePath)

    $OutputDirectory = Join-Path `
        $CollageDirectory `
        "${CollageBaseName}_Extracted"


    $Result.OutputFolder = $OutputDirectory


    try {

        if (-not (Test-Path -LiteralPath $OutputDirectory)) {

            New-Item `
                -Path $OutputDirectory `
                -ItemType Directory `
                -Force |
                Out-Null
        }
    }
    catch {

        $Result.ErrorMessage =
            "Could not create output folder: $($_.Exception.Message)"

        return $Result
    }


    # -----------------------------------------------------------------------
    # Load rendered collage
    # -----------------------------------------------------------------------

    $SourceImage = $null
    $Bitmap      = $null


    try {

        $SourceImage =
            [System.Drawing.Image]::FromFile($CollagePath)

        $Bitmap =
            New-Object System.Drawing.Bitmap(
                $SourceImage.Width,
                $SourceImage.Height,
                [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
            )


        $Graphics =
            [System.Drawing.Graphics]::FromImage($Bitmap)


        try {

            $Graphics.DrawImage(
                $SourceImage,
                0,
                0,
                $SourceImage.Width,
                $SourceImage.Height
            )
        }
        finally {

            $Graphics.Dispose()
        }
    }
    catch {

        if ($SourceImage) {
            $SourceImage.Dispose()
        }

        $Result.ErrorMessage =
            "Could not open collage image: $($_.Exception.Message)"

        return $Result
    }


    # -----------------------------------------------------------------------
    # Display details
    # -----------------------------------------------------------------------

    Write-Host
    Write-Host "CXF        : $CxfPath"
    Write-Host "Collage    : $CollagePath"
    Write-Host "Dimensions : $($Bitmap.Width) x $($Bitmap.Height)"
    Write-Host "Theme      : $Theme"
    Write-Host "Images     : $($Nodes.Count)"
    Write-Host "Output     : $OutputDirectory"


    if ($Theme -ne 'picturegrid') {

        Write-Host `
            "WARNING: Theme is '$Theme' instead of 'picturegrid'." `
            -ForegroundColor Yellow
    }


    # -----------------------------------------------------------------------
    # Process nodes
    # -----------------------------------------------------------------------

    $Index = 0


    foreach ($Node in $Nodes) {

        $Index++


        try {

            $X = [double]::Parse(
                [string]$Node.x,
                [System.Globalization.CultureInfo]::InvariantCulture
            )

            $Y = [double]::Parse(
                [string]$Node.y,
                [System.Globalization.CultureInfo]::InvariantCulture
            )

            $W = [double]::Parse(
                [string]$Node.w,
                [System.Globalization.CultureInfo]::InvariantCulture
            )

            $H = [double]::Parse(
                [string]$Node.h,
                [System.Globalization.CultureInfo]::InvariantCulture
            )

            $Theta = [double]::Parse(
                [string]$Node.theta,
                [System.Globalization.CultureInfo]::InvariantCulture
            )


            $SourceReference = [string]$Node.src


            # ---------------------------------------------------------------
            # Get original filename
            # ---------------------------------------------------------------

            $OriginalFileName =
                $SourceReference -replace '^.*\\', ''


            if ([string]::IsNullOrWhiteSpace($OriginalFileName)) {

                $OriginalFileName =
                    "Image_{0:D3}.jpg" -f $Index
            }


            $OutputBaseName =
                [System.IO.Path]::GetFileNameWithoutExtension(
                    $OriginalFileName
                )

            $OutputFileName =
                "$OutputBaseName.jpg"

            $OutputPath =
                Join-Path `
                    $OutputDirectory `
                    $OutputFileName


            Write-Host `
                "  [$Index/$($Nodes.Count)] $OriginalFileName"


            # ---------------------------------------------------------------
            # Rotated node
            # ---------------------------------------------------------------

            if ([Math]::Abs($Theta) -gt 0.000001) {

                $ThetaDegrees = $Theta * (180.0 / [Math]::PI)

                Write-Host `
                    ("      SKIPPED: Rotated node (theta = {0:N6}, {1:N2} degrees)" -f `
                        $Theta,
                        $ThetaDegrees) `
                    -ForegroundColor Yellow


                $Result.RotatedNodesSkipped++


                $Result.RotatedNodes += [PSCustomObject]@{
                    CollageFile     = [System.IO.Path]::GetFileName($CollagePath)
                    CollagePath     = $CollagePath
                    CxfFile         = [System.IO.Path]::GetFileName($CxfPath)
                    CxfPath         = $CxfPath
                    SourceImage     = $OriginalFileName
                    SourceReference = $SourceReference
                    Theta           = $Theta
                    ThetaDegrees    = [Math]::Round($ThetaDegrees, 3)
                    NodeIndex       = $Index
                }


                continue
            }


            # ---------------------------------------------------------------
            # CXF coordinates -> pixels
            # ---------------------------------------------------------------

            $Left = [Math]::Floor(
                $X * $Bitmap.Width
            )

            $Top = [Math]::Floor(
                $Y * $Bitmap.Height
            )

            $Right = [Math]::Ceiling(
                ($X + $W) * $Bitmap.Width
            )

            $Bottom = [Math]::Ceiling(
                ($Y + $H) * $Bitmap.Height
            )


            # ---------------------------------------------------------------
            # Clamp
            # ---------------------------------------------------------------

            $Left = [Math]::Max(
                0,
                [Math]::Min(
                    $Left,
                    $Bitmap.Width - 1
                )
            )

            $Top = [Math]::Max(
                0,
                [Math]::Min(
                    $Top,
                    $Bitmap.Height - 1
                )
            )

            $Right = [Math]::Max(
                $Left + 1,
                [Math]::Min(
                    $Right,
                    $Bitmap.Width
                )
            )

            $Bottom = [Math]::Max(
                $Top + 1,
                [Math]::Min(
                    $Bottom,
                    $Bitmap.Height
                )
            )


            $RawRectangle =
                New-Object System.Drawing.Rectangle(
                    [int]$Left,
                    [int]$Top,
                    [int]($Right - $Left),
                    [int]($Bottom - $Top)
                )


            # ---------------------------------------------------------------
            # Trim Picasa white spacing
            # ---------------------------------------------------------------

            $CropRectangle =
                Get-TrimmedRectangle `
                    -Bitmap $Bitmap `
                    -Rectangle $RawRectangle


            # ---------------------------------------------------------------
            # Crop
            # ---------------------------------------------------------------

            $CroppedBitmap =
                New-Object System.Drawing.Bitmap(
                    $CropRectangle.Width,
                    $CropRectangle.Height,
                    [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
                )


            $CropGraphics =
                [System.Drawing.Graphics]::FromImage(
                    $CroppedBitmap
                )


            try {

                $DestinationRectangle =
                    New-Object System.Drawing.Rectangle(
                        0,
                        0,
                        $CropRectangle.Width,
                        $CropRectangle.Height
                    )


                $CropGraphics.DrawImage(
                    $Bitmap,
                    $DestinationRectangle,
                    $CropRectangle,
                    [System.Drawing.GraphicsUnit]::Pixel
                )
            }
            finally {

                $CropGraphics.Dispose()
            }


            # ---------------------------------------------------------------
            # Skip existing output files
            # ---------------------------------------------------------------

            if (Test-Path -LiteralPath $OutputPath -PathType Leaf) {

                Write-Host `
                    "      SKIPPED: Output file already exists: $OutputFileName" `
                    -ForegroundColor Yellow

                $Result.ExistingOutputsSkipped++

                $CroppedBitmap.Dispose()

                continue
            }


            # ---------------------------------------------------------------
            # Save
            # ---------------------------------------------------------------

            try {

                Save-Jpeg `
                    -Bitmap $CroppedBitmap `
                    -Path $OutputPath `
                    -Quality $JpegQuality
            }
            finally {

                $CroppedBitmap.Dispose()
            }


            Write-Host `
                "      SAVED: $OutputFileName" `
                -ForegroundColor Green


            $Result.Extracted++
        }
        catch {

            Write-Host `
                "      ERROR: $($_.Exception.Message)" `
                -ForegroundColor Red

            $Result.FailedNodes++
        }
    }


    # -----------------------------------------------------------------------
    # Cleanup image resources
    # -----------------------------------------------------------------------

    if ($Bitmap) {
        $Bitmap.Dispose()
    }

    if ($SourceImage) {
        $SourceImage.Dispose()
    }


    $Result.Success = $true

    return $Result
}


# ===========================================================================
# Load System.Drawing
# ===========================================================================

try {

    Add-Type `
        -AssemblyName System.Drawing `
        -ErrorAction Stop
}
catch {

    Write-Host
    Write-Host `
        "ERROR: Could not load System.Drawing." `
        -ForegroundColor Red

    Write-Host `
        $_.Exception.Message `
        -ForegroundColor Red

    Write-Host

    exit 1
}


# ===========================================================================
# Header
# ===========================================================================

Write-Host
Write-Host `
    "Picasa Collage Extractor" `
    -ForegroundColor Cyan

Write-Host `
    "-------------------------"

Write-Host


# ===========================================================================
# Detect mode
# ===========================================================================

if (Test-Path -LiteralPath $ListFile -PathType Leaf) {

    # =======================================================================
    # BATCH MODE
    # =======================================================================

    Write-Host `
        "Batch mode detected." `
        -ForegroundColor Cyan

    Write-Host `
        "Using: $ListFile"

    Write-Host


    # -----------------------------------------------------------------------
    # Read list as UTF-8
    # -----------------------------------------------------------------------

    $CxfFiles =
        Get-Content `
            -LiteralPath $ListFile `
            -Encoding UTF8 |
        ForEach-Object {
            $_.Trim()
        } |
        Where-Object {
            $_ -and
            -not $_.StartsWith('#')
        }


    Write-Host `
        "CXF files in list : $($CxfFiles.Count)"

    Write-Host


    # -----------------------------------------------------------------------
    # Batch counters
    # -----------------------------------------------------------------------

    $BatchProcessedCollages = 0
    $BatchSuccessful        = 0
    $BatchSkippedMissingCxf = 0
    $BatchSkippedNoImage    = 0
    $BatchFailedCollages    = 0

    $BatchExtractedImages         = 0
    $BatchExistingOutputsSkipped  = 0
    $BatchRotatedNodesSkipped     = 0
    $BatchFailedNodes             = 0

    $BatchRotatedNodes            = @()

    $BatchIndex = 0


    foreach ($CxfPathRaw in $CxfFiles) {

        $BatchIndex++


        $CxfPath =
            Get-CleanPath $CxfPathRaw


        Write-Host
        Write-Host `
            "============================================================" `
            -ForegroundColor DarkGray

        Write-Host `
            "Collage $BatchIndex of $($CxfFiles.Count)" `
            -ForegroundColor Cyan

        Write-Host `
            "============================================================" `
            -ForegroundColor DarkGray


        # -------------------------------------------------------------------
        # CXF exists?
        # -------------------------------------------------------------------

        if (
            -not (
                Test-Path `
                    -LiteralPath $CxfPath `
                    -PathType Leaf
            )
        ) {

            Write-Host
            Write-Host `
                "SKIPPED: CXF file not found" `
                -ForegroundColor Yellow

            Write-Host `
                $CxfPath

            $BatchSkippedMissingCxf++

            continue
        }


        # -------------------------------------------------------------------
        # Find matching collage image
        # -------------------------------------------------------------------

        $CollagePath =
            Get-MatchingCollageImage `
                -CxfPath $CxfPath


        if (-not $CollagePath) {

            Write-Host
            Write-Host `
                "SKIPPED: Matching collage JPG/JPEG/PNG not found" `
                -ForegroundColor Yellow

            Write-Host `
                "CXF: $CxfPath"

            $BatchSkippedNoImage++

            continue
        }


        # -------------------------------------------------------------------
        # Extract
        # -------------------------------------------------------------------

        $BatchProcessedCollages++


        $Result =
            Invoke-PicasaCollageExtraction `
                -CxfPath $CxfPath `
                -CollagePath $CollagePath


        if ($Result.Success) {

            $BatchSuccessful++

            $BatchExtractedImages +=
                $Result.Extracted

            $BatchExistingOutputsSkipped +=
                $Result.ExistingOutputsSkipped

            $BatchRotatedNodesSkipped +=
                $Result.RotatedNodesSkipped

            $BatchFailedNodes +=
                $Result.FailedNodes


            if ($Result.RotatedNodes.Count -gt 0) {

                $BatchRotatedNodes +=
                    $Result.RotatedNodes
            }


            Write-Host
            Write-Host `
                "Collage finished:" `
                -ForegroundColor Cyan

            Write-Host `
                "  Extracted                : $($Result.Extracted)" `
                -ForegroundColor Green

            Write-Host `
                "  Existing outputs skipped : $($Result.ExistingOutputsSkipped)" `
                -ForegroundColor DarkGray

            Write-Host `
                "  Rotated nodes skipped    : $($Result.RotatedNodesSkipped)" `
                -ForegroundColor Yellow

            Write-Host `
                "  Failed                   : $($Result.FailedNodes)" `
                -ForegroundColor Red
        }
        else {

            $BatchFailedCollages++

            Write-Host
            Write-Host `
                "FAILED: $($Result.ErrorMessage)" `
                -ForegroundColor Red
        }
    }


    # =======================================================================
    # Batch summary
    # =======================================================================

    Write-Host
    Write-Host
    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host `
        "Batch extraction finished" `
        -ForegroundColor Cyan

    Write-Host `
        "============================================================" `
        -ForegroundColor Cyan

    Write-Host

    Write-Host `
        "CXF files in list        : $($CxfFiles.Count)"

    Write-Host `
        "Collages processed       : $BatchProcessedCollages"

    Write-Host `
        "Collages successful      : $BatchSuccessful" `
        -ForegroundColor Green

    Write-Host `
        "CXF files missing        : $BatchSkippedMissingCxf" `
        -ForegroundColor Yellow

    Write-Host `
        "Collage images missing   : $BatchSkippedNoImage" `
        -ForegroundColor Yellow

    Write-Host `
        "Collages failed          : $BatchFailedCollages" `
        -ForegroundColor Red

    Write-Host

    Write-Host `
    "Images extracted          : $BatchExtractedImages" `
    -ForegroundColor Green

Write-Host `
    "Existing outputs skipped  : $BatchExistingOutputsSkipped" `
    -ForegroundColor DarkGray

Write-Host `
    "Rotated nodes skipped     : $BatchRotatedNodesSkipped" `
    -ForegroundColor Yellow

Write-Host `
    "Image nodes failed        : $BatchFailedNodes" `
    -ForegroundColor Red

Write-Host


# =======================================================================
# Report rotated nodes
# =======================================================================

if ($BatchRotatedNodes.Count -gt 0) {

    Write-Host `
        "Rotated nodes requiring attention:" `
        -ForegroundColor Yellow

    Write-Host


    if ($BatchRotatedNodes.Count -le 20) {

        foreach ($RotatedNode in $BatchRotatedNodes) {

            Write-Host `
                "  Collage : $($RotatedNode.CollageFile)" `
                -ForegroundColor White

            Write-Host `
                "  Image   : $($RotatedNode.SourceImage)"

            Write-Host `
                ("  Theta   : {0} ({1} degrees)" -f `
                    $RotatedNode.Theta,
                    $RotatedNode.ThetaDegrees)

            Write-Host `
                "  CXF     : $($RotatedNode.CxfPath)" `
                -ForegroundColor DarkGray

            Write-Host
        }
    }
    else {

        $RotatedCsvPath = Join-Path `
            $PSScriptRoot `
            'Picasa_Rotated_Nodes_Skipped.csv'


        $BatchRotatedNodes |
            Export-Csv `
                -LiteralPath $RotatedCsvPath `
                -NoTypeInformation `
                -Encoding UTF8


        Write-Host `
            "$($BatchRotatedNodes.Count) rotated nodes were found." `
            -ForegroundColor Yellow

        Write-Host `
            "The list is too long to display on screen."

        Write-Host

        Write-Host `
            "CSV report:" `
            -ForegroundColor Cyan

        Write-Host `
            $RotatedCsvPath `
            -ForegroundColor Cyan

        Write-Host
    }
}

}
else {

    # =======================================================================
    # INTERACTIVE MODE
    # =======================================================================

    Write-Host `
        "No list_of_cxf_files.txt detected."

    Write-Host `
        "Starting interactive single-collage mode." `
        -ForegroundColor Cyan

    Write-Host


    # -----------------------------------------------------------------------
    # Ask for collage image
    # -----------------------------------------------------------------------

    do {

        $CollagePath =
            Read-Host `
                "Enter or drag-and-drop the finished collage image here"

        $CollagePath =
            Get-CleanPath $CollagePath


        if (
            -not (
                Test-Path `
                    -LiteralPath $CollagePath `
                    -PathType Leaf
            )
        ) {

            Write-Host
            Write-Host `
                "File not found:" `
                -ForegroundColor Yellow

            Write-Host `
                $CollagePath

            Write-Host

            $CollagePath = $null
        }

    }
    until ($CollagePath)


    # -----------------------------------------------------------------------
    # Find matching CXF
    # -----------------------------------------------------------------------

    $AutomaticCxfPath =
        [System.IO.Path]::ChangeExtension(
            $CollagePath,
            '.cxf'
        )


    if (
        Test-Path `
            -LiteralPath $AutomaticCxfPath `
            -PathType Leaf
    ) {

        Write-Host
        Write-Host `
            "Matching CXF found automatically:" `
            -ForegroundColor Green

        Write-Host `
            $AutomaticCxfPath

        $CxfPath =
            $AutomaticCxfPath
    }
    else {

        Write-Host
        Write-Host `
            "A matching CXF was not found automatically." `
            -ForegroundColor Yellow

        Write-Host


        do {

            $CxfPath =
                Read-Host `
                    "Enter or drag-and-drop the matching .cxf file here"

            $CxfPath =
                Get-CleanPath $CxfPath


            if (
                -not (
                    Test-Path `
                        -LiteralPath $CxfPath `
                        -PathType Leaf
                )
            ) {

                Write-Host
                Write-Host `
                    "File not found:" `
                    -ForegroundColor Yellow

                Write-Host `
                    $CxfPath

                Write-Host

                $CxfPath = $null
            }

        }
        until ($CxfPath)
    }


    # -----------------------------------------------------------------------
    # Extract
    # -----------------------------------------------------------------------

    $Result =
        Invoke-PicasaCollageExtraction `
            -CxfPath $CxfPath `
            -CollagePath $CollagePath


    # -----------------------------------------------------------------------
    # Interactive summary
    # -----------------------------------------------------------------------

    Write-Host
    Write-Host `
        "-------------------------"

    Write-Host `
        "Extraction finished" `
        -ForegroundColor Cyan

    Write-Host `
        "-------------------------"


    if ($Result.Success) {

    Write-Host `
        "Extracted                : $($Result.Extracted)" `
        -ForegroundColor Green

    Write-Host `
        "Existing outputs skipped : $($Result.ExistingOutputsSkipped)" `
        -ForegroundColor DarkGray

    Write-Host `
        "Rotated nodes skipped    : $($Result.RotatedNodesSkipped)" `
        -ForegroundColor Yellow

    Write-Host `
        "Failed                   : $($Result.FailedNodes)" `
        -ForegroundColor Red

    Write-Host


    # -----------------------------------------------------------------------
    # Show rotated nodes in interactive mode
    # -----------------------------------------------------------------------

    if ($Result.RotatedNodes.Count -gt 0) {

        Write-Host `
            "Rotated nodes requiring attention:" `
            -ForegroundColor Yellow

        Write-Host

        foreach ($RotatedNode in $Result.RotatedNodes) {

            Write-Host `
                "  Image : $($RotatedNode.SourceImage)"

            Write-Host `
                ("  Theta : {0} ({1} degrees)" -f `
                    $RotatedNode.Theta,
                    $RotatedNode.ThetaDegrees)

            Write-Host
        }
    }


    Write-Host `
        "Output folder:"

    Write-Host `
        $Result.OutputFolder `
        -ForegroundColor Cyan
}
else {

    Write-Host `
        "FAILED: $($Result.ErrorMessage)" `
        -ForegroundColor Red
}

Write-Host
}