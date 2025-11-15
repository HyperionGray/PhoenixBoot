/*
 * UUEFI - Universal UEFI Diagnostic Application
 * 
 * A simple UEFI application that displays system information
 * and provides a diagnostic interface for PhoenixGuard.
 * 
 * Unlike NuclearBoot, this does not enforce strict security requirements
 * and can run in both secure and non-secure boot modes.
 */

#include <Uefi.h>
#include <Library/UefiApplicationEntryPoint.h>
#include <Library/UefiLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiRuntimeServicesTableLib.h>
#include <Library/PrintLib.h>
#include <Protocol/SimpleFileSystem.h>
#include <Protocol/LoadedImage.h>
#include <Guid/FileInfo.h>
#include <Guid/GlobalVariable.h>

#define UUEFI_VERSION L"1.0.0"

/**
  Get Secure Boot status without failing if unavailable
  
  @param SecureBoot  Pointer to store Secure Boot status (1=enabled, 0=disabled)
  @param SetupMode   Pointer to store Setup Mode status (1=setup, 0=user)
  
  @retval EFI_SUCCESS  Status retrieved successfully
  @retval Other        Error occurred, values set to 0
**/
EFI_STATUS
GetSecureBootStatus(
  OUT UINT8 *SecureBoot,
  OUT UINT8 *SetupMode
  )
{
  EFI_STATUS Status;
  UINT8 Value;
  UINTN Size;
  EFI_GUID GlobalVar = EFI_GLOBAL_VARIABLE;

  *SecureBoot = 0;
  *SetupMode = 0;

  // Check SecureBoot variable
  Size = sizeof(Value);
  Status = gRT->GetVariable(L"SecureBoot", &GlobalVar, NULL, &Size, &Value);
  if (!EFI_ERROR(Status)) {
    *SecureBoot = Value;
  }

  // Check SetupMode variable
  Size = sizeof(Value);
  Status = gRT->GetVariable(L"SetupMode", &GlobalVar, NULL, &Size, &Value);
  if (!EFI_ERROR(Status)) {
    *SetupMode = Value;
  }

  return EFI_SUCCESS;
}

/**
  Display firmware vendor and version information
**/
VOID
DisplayFirmwareInfo(
  IN EFI_SYSTEM_TABLE *SystemTable
  )
{
  Print(L"\n=== Firmware Information ===\n");
  Print(L"Vendor: %s\n", SystemTable->FirmwareVendor);
  Print(L"Revision: 0x%08x\n", SystemTable->FirmwareRevision);
  Print(L"UEFI Version: %d.%d\n", 
    (SystemTable->Hdr.Revision >> 16) & 0xFFFF,
    SystemTable->Hdr.Revision & 0xFFFF);
}

/**
  Display memory map summary
**/
VOID
DisplayMemoryInfo(VOID)
{
  EFI_STATUS Status;
  UINTN MemMapSize = 0;
  EFI_MEMORY_DESCRIPTOR *MemMap = NULL;
  UINTN MapKey;
  UINTN DescriptorSize;
  UINT32 DescriptorVersion;
  UINT64 TotalMemory = 0;
  UINT64 AvailableMemory = 0;

  Print(L"\n=== Memory Information ===\n");

  // Get memory map size
  Status = gBS->GetMemoryMap(&MemMapSize, MemMap, &MapKey, &DescriptorSize, &DescriptorVersion);
  if (Status == EFI_BUFFER_TOO_SMALL) {
    MemMapSize += 2 * DescriptorSize; // Add extra space
    MemMap = AllocatePool(MemMapSize);
    if (MemMap != NULL) {
      Status = gBS->GetMemoryMap(&MemMapSize, MemMap, &MapKey, &DescriptorSize, &DescriptorVersion);
      if (!EFI_ERROR(Status)) {
        EFI_MEMORY_DESCRIPTOR *Entry;
        UINTN EntryCount = MemMapSize / DescriptorSize;
        
        for (UINTN i = 0; i < EntryCount; i++) {
          Entry = (EFI_MEMORY_DESCRIPTOR *)((UINT8 *)MemMap + (i * DescriptorSize));
          TotalMemory += Entry->NumberOfPages * 4096; // 4KB pages
          
          // Count conventional memory as available
          if (Entry->Type == EfiConventionalMemory || Entry->Type == EfiBootServicesData || Entry->Type == EfiBootServicesCode) {
            AvailableMemory += Entry->NumberOfPages * 4096;
          }
        }
        
        Print(L"Total Memory: %lu MB\n", TotalMemory / (1024 * 1024));
        Print(L"Available Memory: %lu MB\n", AvailableMemory / (1024 * 1024));
      }
      FreePool(MemMap);
    }
  }
}

/**
  Display boot configuration information
**/
VOID
DisplayBootInfo(VOID)
{
  EFI_STATUS Status;
  UINT16 *BootOrder = NULL;
  UINTN Size = 0;
  EFI_GUID GlobalVar = EFI_GLOBAL_VARIABLE;

  Print(L"\n=== Boot Configuration ===\n");

  // Get BootOrder variable
  Status = gRT->GetVariable(L"BootOrder", &GlobalVar, NULL, &Size, NULL);
  if (Status == EFI_BUFFER_TOO_SMALL) {
    BootOrder = AllocatePool(Size);
    if (BootOrder != NULL) {
      Status = gRT->GetVariable(L"BootOrder", &GlobalVar, NULL, &Size, BootOrder);
      if (!EFI_ERROR(Status)) {
        UINTN Count = Size / sizeof(UINT16);
        Print(L"Boot Order: ");
        for (UINTN i = 0; i < Count; i++) {
          Print(L"%04x ", BootOrder[i]);
        }
        Print(L"\n");
      }
      FreePool(BootOrder);
    }
  }
}

/**
  Display security status
**/
VOID
DisplaySecurityInfo(VOID)
{
  UINT8 SecureBoot = 0;
  UINT8 SetupMode = 0;

  Print(L"\n=== Security Status ===\n");

  GetSecureBootStatus(&SecureBoot, &SetupMode);
  
  Print(L"Secure Boot: %s\n", SecureBoot ? L"Enabled" : L"Disabled");
  Print(L"Setup Mode: %s\n", SetupMode ? L"Yes" : L"No");
  
  if (SecureBoot && !SetupMode) {
    Print(L"Status: ✓ Secure Boot active and configured\n");
  } else if (!SecureBoot) {
    Print(L"Status: ⚠ Secure Boot disabled\n");
  } else if (SetupMode) {
    Print(L"Status: ⚠ In setup mode - keys not enrolled\n");
  }
}

/**
  Read and display ESP UUID if available
**/
VOID
DisplayBuildInfo(
  IN EFI_HANDLE ImageHandle
  )
{
  EFI_STATUS Status;
  EFI_LOADED_IMAGE_PROTOCOL *LoadedImage = NULL;
  EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *Fs = NULL;
  EFI_FILE_PROTOCOL *Root = NULL;
  EFI_FILE_PROTOCOL *UuidFile = NULL;

  Print(L"\n=== Build Information ===\n");

  Status = gBS->HandleProtocol(ImageHandle, &gEfiLoadedImageProtocolGuid, (VOID **)&LoadedImage);
  if (EFI_ERROR(Status) || LoadedImage == NULL) {
    Print(L"Could not read build information\n");
    return;
  }

  // Check if DeviceHandle is valid before using it
  if (LoadedImage->DeviceHandle == NULL) {
    Print(L"ESP UUID: Not available (no device handle)\n");
    return;
  }

  Status = gBS->HandleProtocol(LoadedImage->DeviceHandle, &gEfiSimpleFileSystemProtocolGuid, (VOID **)&Fs);
  if (EFI_ERROR(Status) || Fs == NULL) {
    Print(L"Could not access file system\n");
    return;
  }

  Status = Fs->OpenVolume(Fs, &Root);
  if (EFI_ERROR(Status) || Root == NULL) {
    Print(L"Could not open volume\n");
    return;
  }

  // Try to read ESP_UUID.txt
  Status = Root->Open(Root, &UuidFile, L"\\EFI\\PhoenixGuard\\ESP_UUID.txt", EFI_FILE_MODE_READ, 0);
  if (!EFI_ERROR(Status) && UuidFile) {
    UINTN BufSize = 256;
    UINT8 *RawBuf = AllocateZeroPool(BufSize);
    if (RawBuf) {
      UINTN ReadSize = BufSize - 1;
      Status = UuidFile->Read(UuidFile, &ReadSize, RawBuf);
      if (!EFI_ERROR(Status) && ReadSize > 0) {
        // Convert ASCII to CHAR16
        CHAR16 *Buf = AllocateZeroPool((ReadSize + 1) * sizeof(CHAR16));
        if (Buf) {
          for (UINTN i = 0; i < ReadSize; i++) {
            Buf[i] = (CHAR16)RawBuf[i];
          }
          Buf[ReadSize] = 0;
          Print(L"ESP UUID: %s\n", Buf);
          FreePool(Buf);
        }
      }
      FreePool(RawBuf);
    }
    UuidFile->Close(UuidFile);
  } else {
    Print(L"ESP UUID: Not available\n");
  }

  if (Root) Root->Close(Root);
}

/**
  Main entry point for UUEFI
  
  @param ImageHandle  The firmware allocated handle for the EFI image.
  @param SystemTable  A pointer to the EFI System Table.
  
  @retval EFI_SUCCESS  Application completed successfully
**/
EFI_STATUS
EFIAPI
UefiMain (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  // Clear screen and reset console
  if (gST && gST->ConOut) {
    gST->ConOut->Reset(gST->ConOut, TRUE);
    gST->ConOut->ClearScreen(gST->ConOut);
  }
  if (gST && gST->ConIn) {
    gST->ConIn->Reset(gST->ConIn, FALSE);
  }

  // Display banner
  Print(L"\n");
  Print(L"╔════════════════════════════════════════════╗\n");
  Print(L"║  🔥 PhoenixGuard UUEFI %s         ║\n", UUEFI_VERSION);
  Print(L"║  Universal UEFI Diagnostic Tool           ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");

  // Display marker for test detection
  Print(L"\n[UUEFI-START]\n");

  // Display all system information
  DisplayFirmwareInfo(SystemTable);
  DisplayMemoryInfo();
  DisplaySecurityInfo();
  DisplayBootInfo();
  DisplayBuildInfo(ImageHandle);

  // Display completion marker
  Print(L"\n[UUEFI-COMPLETE]\n");

  // Wait for user input before exiting
  Print(L"\n\nPress any key to return to firmware...\n");
  
  EFI_INPUT_KEY Key;
  UINTN Index;
  gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
  gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);

  Print(L"\nReturning to firmware...\n");

  return EFI_SUCCESS;
}
