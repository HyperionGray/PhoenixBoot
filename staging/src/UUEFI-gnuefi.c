/*
 * UUEFI - Universal UEFI Diagnostic Application (GNU-EFI version)
 * 
 * A simple UEFI application that displays system information
 * without strict security requirements.
 */

#include <efi.h>
#include <efilib.h>

#define UUEFI_VERSION L"1.0.0-gnuefi"

EFI_STATUS
EFIAPI
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    EFI_STATUS Status;
    EFI_INPUT_KEY Key;
    UINT8 SecureBoot = 0;
    UINT8 SetupMode = 0;
    UINTN Size;
    
    // Initialize gnu-efi library
    InitializeLib(ImageHandle, SystemTable);
    
    // Clear screen
    uefi_call_wrapper(ST->ConOut->ClearScreen, 1, ST->ConOut);
    
    // Display banner
    Print(L"\n");
    Print(L"╔════════════════════════════════════════════╗\n");
    Print(L"║  🔥 PhoenixGuard UUEFI %s    ║\n", UUEFI_VERSION);
    Print(L"║  Universal UEFI Diagnostic Tool           ║\n");
    Print(L"╚════════════════════════════════════════════╝\n");
    
    // Display marker for test detection
    Print(L"\n[UUEFI-START]\n");
    
    // Firmware Information
    Print(L"\n=== Firmware Information ===\n");
    Print(L"Vendor: %s\n", ST->FirmwareVendor);
    Print(L"Revision: 0x%08x\n", ST->FirmwareRevision);
    Print(L"UEFI Version: %d.%d\n", 
        (ST->Hdr.Revision >> 16) & 0xFFFF,
        ST->Hdr.Revision & 0xFFFF);
    
    // Security Status
    Print(L"\n=== Security Status ===\n");
    
    // Try to get SecureBoot variable
    Size = sizeof(SecureBoot);
    Status = uefi_call_wrapper(RT->GetVariable, 5,
        L"SecureBoot",
        &gEfiGlobalVariableGuid,
        NULL,
        &Size,
        &SecureBoot);
    
    if (EFI_ERROR(Status)) {
        Print(L"Secure Boot: Unknown (cannot read variable)\n");
    } else {
        Print(L"Secure Boot: %s\n", SecureBoot ? L"Enabled" : L"Disabled");
    }
    
    // Try to get SetupMode variable
    Size = sizeof(SetupMode);
    Status = uefi_call_wrapper(RT->GetVariable, 5,
        L"SetupMode",
        &gEfiGlobalVariableGuid,
        NULL,
        &Size,
        &SetupMode);
    
    if (!EFI_ERROR(Status)) {
        Print(L"Setup Mode: %s\n", SetupMode ? L"Yes" : L"No");
    }
    
    // Status interpretation
    if (SecureBoot && !SetupMode) {
        Print(L"Status: ✓ Secure Boot active and configured\n");
    } else if (!SecureBoot) {
        Print(L"Status: ⚠ Secure Boot disabled\n");
    } else if (SetupMode) {
        Print(L"Status: ⚠ In setup mode - keys not enrolled\n");
    }
    
    // Memory Information
    Print(L"\n=== Memory Information ===\n");
    UINTN MemMapSize = 0;
    EFI_MEMORY_DESCRIPTOR *MemMap = NULL;
    UINTN MapKey;
    UINTN DescriptorSize;
    UINT32 DescriptorVersion;
    UINT64 TotalMemory = 0;
    UINT64 AvailableMemory = 0;
    
    // Get memory map size
    Status = uefi_call_wrapper(BS->GetMemoryMap, 5,
        &MemMapSize, MemMap, &MapKey, &DescriptorSize, &DescriptorVersion);
    
    if (Status == EFI_BUFFER_TOO_SMALL) {
        MemMapSize += 2 * DescriptorSize;
        MemMap = AllocatePool(MemMapSize);
        if (MemMap) {
            Status = uefi_call_wrapper(BS->GetMemoryMap, 5,
                &MemMapSize, MemMap, &MapKey, &DescriptorSize, &DescriptorVersion);
            
            if (!EFI_ERROR(Status)) {
                UINTN EntryCount = MemMapSize / DescriptorSize;
                EFI_MEMORY_DESCRIPTOR *Entry;
                
                for (UINTN i = 0; i < EntryCount; i++) {
                    Entry = (EFI_MEMORY_DESCRIPTOR *)((UINT8 *)MemMap + (i * DescriptorSize));
                    TotalMemory += Entry->NumberOfPages * 4096;
                    
                    if (Entry->Type == EfiConventionalMemory ||
                        Entry->Type == EfiBootServicesData ||
                        Entry->Type == EfiBootServicesCode) {
                        AvailableMemory += Entry->NumberOfPages * 4096;
                    }
                }
                
                Print(L"Total Memory: %lu MB\n", TotalMemory / (1024 * 1024));
                Print(L"Available Memory: %lu MB\n", AvailableMemory / (1024 * 1024));
            }
            FreePool(MemMap);
        }
    }
    
    // Boot Configuration
    Print(L"\n=== Boot Configuration ===\n");
    UINT16 *BootOrder = NULL;
    Size = 0;
    
    Status = uefi_call_wrapper(RT->GetVariable, 5,
        L"BootOrder",
        &gEfiGlobalVariableGuid,
        NULL,
        &Size,
        NULL);
    
    if (Status == EFI_BUFFER_TOO_SMALL) {
        BootOrder = AllocatePool(Size);
        if (BootOrder) {
            Status = uefi_call_wrapper(RT->GetVariable, 5,
                L"BootOrder",
                &gEfiGlobalVariableGuid,
                NULL,
                &Size,
                BootOrder);
            
            if (!EFI_ERROR(Status)) {
                UINTN Count = Size / sizeof(UINT16);
                Print(L"Boot Order: ");
                for (UINTN i = 0; i < Count && i < 10; i++) {
                    Print(L"%04x ", BootOrder[i]);
                }
                Print(L"\n");
            }
            FreePool(BootOrder);
        }
    }
    
    // Display completion marker
    Print(L"\n[UUEFI-COMPLETE]\n");
    
    // Wait for user input
    Print(L"\n\nPress any key to return to firmware...\n");
    
    uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
    uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
    
    Print(L"\nReturning to firmware...\n");
    
    return EFI_SUCCESS;
}
