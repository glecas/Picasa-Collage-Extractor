# Picasa-Collage-Extractor
A PowerShell utility that splits Google Picasa collages into separate image files using the original `.cxf` collage layout.

It is primarily intended for recovering the individual **visible images** from old Picasa collages when the original source photographs are no longer available.

<img width="1495" height="702" alt="image" src="https://github.com/user-attachments/assets/d5dd23ff-a2aa-4dbc-8f30-beff57d4f3b1" />

## What it does

Picasa collage projects can have two useful files:

- The final rendered collage, such as `MyCollage.jpg`
- A corresponding `.cxf` file containing the collage layout

Picasa Collage Extractor reads the layout information from the `.cxf` file and uses it to crop the individual visible images from the rendered collage.

For example:

```text
2006-12-03_Tomtecupen.cxf
2006-12-03_Tomtecupen.jpg
````

becomes:

```text
2006-12-03_Tomtecupen_Extracted\
    P1000896.jpg
    P1000903.jpg
    P1000913.jpg
    ...
```
## Why this exists

Older Google Picasa installations could create collages while storing their layout information separately in `.cxf` files.

If the original source photographs were later deleted but the rendered collage and `.cxf` file survived, Picasa itself may no longer be able to reconstruct or split the collage.

This utility uses the surviving layout information to recover each visible image area directly from the final rendered collage.

## Important limitation

This tool does **not** recover the original source photographs.

It extracts the portions of those photographs that are visible in the final rendered collage.

If Picasa cropped part of an original photograph when creating the collage, that hidden area does not exist in the rendered collage and therefore cannot be recovered.

## Features

* Extracts individual image tiles from Picasa collages
* Uses the original `.cxf` layout metadata
* Supports both interactive and batch processing
* Automatically finds matching `.jpg`, `.jpeg`, or `.png` collage images
* Creates a separate `_Extracted` folder beside each collage
* Preserves original files — source collages and `.cxf` files are never modified
* Skips already extracted images instead of overwriting or creating duplicates
* Handles missing `.cxf` or collage files gracefully in batch mode
* Supports UTF-8 paths and filenames, including characters such as `Å`, `Ä`, `Ö`, and `é`
* Reports processed, skipped, missing, and failed files
* Detects rotated CXF nodes and reports them separately
* Can export a CSV report when many rotated nodes are detected

## Requirements

* Windows
* Windows PowerShell
* .NET / `System.Drawing`

No additional PowerShell modules are required.

## Usage

Download:

```text
Picasa_Collage_Extractor.ps1
```

The script automatically selects one of two operating modes.

---

## Interactive mode

If there is **no** `list_of_cxf_files.txt` file beside the script, interactive mode is used.

Run:

```powershell
.\Picasa_Collage_Extractor.ps1
```

<img width="695" height="277" alt="image" src="https://github.com/user-attachments/assets/d01cb90f-c235-4c90-a15d-6f1e09c8a43c" />

The script will ask you to enter or drag-and-drop the finished collage image into the PowerShell window.

Example:

```text
G:\Photos\2006\2006-12-03_Tomtecupen.jpg
```

The script then automatically looks for:

```text
G:\Photos\2006\2006-12-03_Tomtecupen.cxf
```

If the matching `.cxf` file cannot be found automatically, you will be prompted to provide it manually.

Extracted images are written to:

```text
G:\Photos\2006\2006-12-03_Tomtecupen_Extracted\
```

---

## Batch mode

To process multiple collages automatically, create:

```text
list_of_cxf_files.txt
```

in the same folder as the PowerShell script.

Example repository/work folder:

```text
Picasa_Collage_Extractor.ps1
list_of_cxf_files.txt
```
<img width="194" height="64" alt="image" src="https://github.com/user-attachments/assets/0f6c4a7f-ce85-4a86-8e1f-bf5b3d0f8f7f" />

Add one `.cxf` path per line:

```text
D:\Photos\2006\2006-12-03_Tomtecupen.cxf
D:\Photos\2007\2007-10-15_Budapest.cxf
D:\Photos\2008\Vacation\Holiday Collage.cxf
```

Then run:

```powershell
.\Picasa_Collage_Extractor.ps1
```

The presence of `list_of_cxf_files.txt` automatically enables batch mode.

<img width="1022" height="607" alt="WindowsTerminal_Y64OZNN4iC" src="https://github.com/user-attachments/assets/81f39b45-675c-484d-a7f5-59fc967a3157" />

For every `.cxf` file, the script looks for a rendered collage with the same filename using these extensions, in order:

```text
.jpg
.jpeg
.png
```

For example:

```text
D:\Photos\Holiday.cxf
```

will cause the script to try:

```text
D:\Photos\Holiday.jpg
D:\Photos\Holiday.jpeg
D:\Photos\Holiday.png
```

If no matching collage image exists, that collage is skipped and batch processing continues.

## Existing output files

The script is safe to run repeatedly.

If an extracted image already exists:

```text
P1000896.jpg
```

the script skips it.

It will **not** create files such as:

```text
P1000896_2.jpg
P1000896_3.jpg
```

This makes interrupted or repeated batch runs safe and predictable.

## Batch summary

At the end of a batch run, the script displays a summary similar to:

```text
============================================================
Batch extraction finished
============================================================

CXF files in list         : 252
Collages processed        : 252
Collages successful       : 252
CXF files missing         : 0
Collage images missing    : 0
Collages failed           : 0

Images extracted          : 1065
Existing outputs skipped  : 0
Rotated nodes skipped     : 0
Image nodes failed        : 0
```

## Rotated images

CXF nodes containing a non-zero rotation value (`theta`) are currently detected and skipped rather than being extracted incorrectly.

If more than 20 rotated nodes are found during a batch run, the script creates:

```text
Picasa_Rotated_Nodes_Skipped.csv
```

beside the PowerShell script.

The report includes information such as:

* Collage filename
* Collage path
* CXF filename
* CXF path
* Original source image filename
* Original source reference
* Rotation value
* Rotation in degrees
* Node index

## UTF-8 and special characters

`list_of_cxf_files.txt` is read as UTF-8.

Paths containing characters such as:

```text
Å
Ä
Ö
å
ä
ö
é
```

are therefore supported.

It is recommended that `list_of_cxf_files.txt` itself is saved as UTF-8.

## Safety

The script does not modify:

* The rendered collage
* The `.cxf` file
* Any original source photographs that may still exist

All extracted images are written to a separate folder ending in:

```text
_Extracted
```

## License

This project is licensed under the MIT License.
