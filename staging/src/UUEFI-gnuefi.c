/*
 * UUEFI - Universal UEFI Diagnostic Application (GNU-EFI version)
 * 
 * Enhanced with variable management and security analysis capabilities.
 * Displays system information and provides interactive diagnostics.
 */

#include <efi.h>
#include <efilib.h>

#define UUEFI_VERSION L"2.0.0-gnuefi"
#define MAX_BOOT_ENTRIES 10
#define MAX_VARIABLE_NAME_SIZE 1024
#define MAX_VARIABLES 500

// Variable categories
typedef enum {
  VAR_CAT_BOOT,
  VAR_CAT_SECURITY,
  VAR_CAT_VENDOR,
  VAR_CAT_UNKNOWN
} VARIABLE_CATEGORY;

// Variable information structure
typedef struct {
  CHAR16 Name[MAX_VARIABLE_NAME_SIZE];
  EFI_GUID VendorGuid;
  UINTN DataSize;
  UINT32 Attributes;
  VARIABLE_CATEGORY Category;
  BOOLEAN IsSuspicious;
} VARIABLE_INFO;

// Global state
STATIC VARIABLE_INFO *gVariables = NULL;
STATIC UINTN gVariableCount = 0;
STATIC UINTN gSuspiciousCount = 0;

/**
  Compare two GUIDs
**/
BOOLEAN
CompareGuid(EFI_GUID *Guid1, EFI_GUID *Guid2)
{
    UINT32 *g1 = (UINT32 *)Guid1;
    UINT32 *g2 = (UINT32 *)Guid2;
    return (g1[0] == g2[0] && g1[1] == g2[1] && g1[2] == g2[2] && g1[3] == g2[3]);
}

/**
  Categorize a variable
**/
VARIABLE_CATEGORY
CategorizeVariable(CHAR16 *Name, EFI_GUID *Guid)
{
    if (CompareGuid(Guid, &gEfiGlobalVariableGuid)) {
        if (StrnCmp(Name, L"Boot", 4) == 0 || 
            StriCmp(Name, L"BootOrder") == 0) {
            return VAR_CAT_BOOT;
        }
        if (StriCmp(Name, L"SecureBoot") == 0 ||
            StriCmp(Name, L"PK") == 0 ||
            StriCmp(Name, L"KEK") == 0 ||
            StriCmp(Name, L"db") == 0 ||
            StriCmp(Name, L"dbx") == 0) {
            return VAR_CAT_SECURITY;
        }
    }
    return VAR_CAT_VENDOR;
}

/**
  Check for suspicious patterns
**/
VOID
CheckVariableHeuristics(VARIABLE_INFO *var)
{
    var->IsSuspicious = FALSE;
    
    // Large variables (except db/dbx)
    if (var->DataSize > 32768 && 
        StriCmp(var->Name, L"db") != 0 && 
        StriCmp(var->Name, L"dbx") != 0) {
        var->IsSuspicious = TRUE;
        gSuspiciousCount++;
    }
    
    // Suspicious keywords in vendor variables
    if (var->Category == VAR_CAT_VENDOR) {
        if (StrStr(var->Name, L"Debug") || 
            StrStr(var->Name, L"Test") ||
            StrStr(var->Name, L"Backdoor")) {
            var->IsSuspicious = TRUE;
            gSuspiciousCount++;
        }
    }
}

/**
  Enumerate all EFI variables
**/
EFI_STATUS
EnumerateAllVariables(VOID)
{
    EFI_STATUS Status;
    CHAR16 VariableName[MAX_VARIABLE_NAME_SIZE];
    EFI_GUID VendorGuid;
    UINTN NameSize;
    UINTN DataSize;
    UINT32 Attributes;
    
    Print(L"\n=== Enumerating All EFI Variables ===\n");
    
    gVariables = AllocateZeroPool(MAX_VARIABLES * sizeof(VARIABLE_INFO));
    if (!gVariables) {
        Print(L"Failed to allocate memory\n");
        return EFI_OUT_OF_RESOURCES;
    }
    
    gVariableCount = 0;
    gSuspiciousCount = 0;
    
    VariableName[0] = 0;
    NameSize = sizeof(VariableName);
    
    while (TRUE) {
        Status = uefi_call_wrapper(RT->GetNextVariableName, 3,
                                   &NameSize, VariableName, &VendorGuid);
        
        if (EFI_ERROR(Status)) {
            if (Status == EFI_NOT_FOUND) {
                break;
            }
            if (Status == EFI_BUFFER_TOO_SMALL) {
                NameSize = sizeof(VariableName);
                continue;
            }
            break;
        }
        
        if (gVariableCount >= MAX_VARIABLES) {
            Print(L"Warning: Maximum variable count reached\n");
            break;
        }
        
        DataSize = 0;
        Status = uefi_call_wrapper(RT->GetVariable, 5,
                                   VariableName, &VendorGuid, 
                                   &Attributes, &DataSize, NULL);
        
        if (Status == EFI_BUFFER_TOO_SMALL || Status == EFI_SUCCESS) {
            VARIABLE_INFO *var = &gVariables[gVariableCount];
            
            StrCpy(var->Name, VariableName);
            CopyMem(&var->VendorGuid, &VendorGuid, sizeof(EFI_GUID));
            var->DataSize = DataSize;
            var->Attributes = Attributes;
            var->Category = CategorizeVariable(VariableName, &VendorGuid);
            
            CheckVariableHeuristics(var);
            
            gVariableCount++;
        }
        
        NameSize = sizeof(VariableName);
    }
    
    Print(L"Found %lu EFI variables\n", gVariableCount);
    Print(L"Suspicious items detected: %lu\n", gSuspiciousCount);
    
    return EFI_SUCCESS;
}

/**
  Display variables by category
**/
VOID
DisplayVariablesByCategory(INTN Category)
{
    CHAR16 *CategoryNames[] = {
        L"Boot Configuration",
        L"Security",
        L"Vendor-Specific",
        L"Unknown"
    };
    
    for (UINTN cat = 0; cat < 4; cat++) {
        if (Category >= 0 && (UINTN)Category != cat) {
            continue;
        }
        
        UINTN count = 0;
        for (UINTN i = 0; i < gVariableCount; i++) {
            if (gVariables[i].Category == cat) {
                count++;
            }
        }
        
        if (count == 0) continue;
        
        Print(L"\n--- %s (%lu variables) ---\n", CategoryNames[cat], count);
        
        for (UINTN i = 0; i < gVariableCount; i++) {
            if (gVariables[i].Category == cat) {
                Print(L"  %s", gVariables[i].Name);
                if (gVariables[i].IsSuspicious) {
                    Print(L" ⚠ SUSPICIOUS");
                }
                Print(L"\n    Size: %lu bytes\n", gVariables[i].DataSize);
            }
        }
    }
}

/**
  Display security report
**/
VOID
DisplaySecurityReport(VOID)
{
    Print(L"\n");
    Print(L"╔════════════════════════════════════════════╗\n");
    Print(L"║     SECURITY ANALYSIS REPORT              ║\n");
    Print(L"╚════════════════════════════════════════════╝\n");
    Print(L"\nTotal Variables: %lu\n", gVariableCount);
    Print(L"Suspicious Items: %lu\n\n", gSuspiciousCount);
    
    if (gSuspiciousCount == 0) {
        Print(L"✓ No suspicious activity detected\n");
        return;
    }
    
    Print(L"Suspicious Variables:\n");
    for (UINTN i = 0; i < gVariableCount; i++) {
        if (gVariables[i].IsSuspicious) {
            Print(L"  • %s (Size: %lu bytes)\n", 
                  gVariables[i].Name, gVariables[i].DataSize);
        }
    }
}

/**
  Interactive menu
**/
VOID
ShowInteractiveMenu(VOID)
{
    EFI_INPUT_KEY Key;
    UINTN MapKey;
    BOOLEAN exitMenu = FALSE;
    
    while (!exitMenu) {
        Print(L"\n");
        Print(L"╔════════════════════════════════════════════╗\n");
        Print(L"║        UUEFI INTERACTIVE MENU             ║\n");
        Print(L"╚════════════════════════════════════════════╝\n");
        Print(L"\n");
        Print(L"1. View All Variables\n");
        Print(L"2. View Boot Variables\n");
        Print(L"3. View Security Variables\n");
        Print(L"4. View Vendor Variables\n");
        Print(L"5. Show Security Report\n");
        Print(L"6. Re-scan Variables\n");
        Print(L"Q. Return\n");
        Print(L"\nSelect: ");
        
        uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
        uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
        Print(L"%c\n", Key.UnicodeChar);
        
        switch (Key.UnicodeChar) {
            case L'1':
                DisplayVariablesByCategory(-1);
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'2':
                DisplayVariablesByCategory(VAR_CAT_BOOT);
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'3':
                DisplayVariablesByCategory(VAR_CAT_SECURITY);
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'4':
                DisplayVariablesByCategory(VAR_CAT_VENDOR);
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'5':
                DisplaySecurityReport();
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'6':
                FreePool(gVariables);
                EnumerateAllVariables();
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'Q':
            case L'q':
                exitMenu = TRUE;
                break;
        }
    }
}

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
    Print(L"║  Enhanced: Variable Mgmt & Security        ║\n");
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
                for (UINTN i = 0; i < Count && i < MAX_BOOT_ENTRIES; i++) {
                    Print(L"%04x ", BootOrder[i]);
                }
                Print(L"\n");
            }
            FreePool(BootOrder);
        }
    }
    
    // NEW: Advanced variable management and security
    Print(L"\n");
    Print(L"═══════════════════════════════════════════════\n");
    Print(L"  ADVANCED: Variable Management & Security\n");
    Print(L"═══════════════════════════════════════════════\n");
    
    EnumerateAllVariables();
    
    if (gSuspiciousCount > 0) {
        Print(L"\n⚠ ALERT: %lu suspicious items detected!\n", gSuspiciousCount);
        Print(L"  Use the interactive menu to view details.\n");
    } else {
        Print(L"\n✓ No suspicious activity detected\n");
    }
    
    // Display completion marker
    Print(L"\n[UUEFI-COMPLETE]\n");
    
    // Interactive options
    Print(L"\n\nOptions:\n");
    Print(L"  M - Enter Interactive Menu\n");
    Print(L"  R - Show Security Report\n");
    Print(L"  Q - Return to Firmware\n");
    Print(L"\nSelect: ");
    
    while (TRUE) {
        uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
        uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
        Print(L"%c\n", Key.UnicodeChar);
        
        if (Key.UnicodeChar == L'M' || Key.UnicodeChar == L'm') {
            ShowInteractiveMenu();
            Print(L"\nOptions: M - Menu, R - Report, Q - Quit\nSelect: ");
        } else if (Key.UnicodeChar == L'R' || Key.UnicodeChar == L'r') {
            DisplaySecurityReport();
            Print(L"\nOptions: M - Menu, R - Report, Q - Quit\nSelect: ");
        } else if (Key.UnicodeChar == L'Q' || Key.UnicodeChar == L'q') {
            break;
        } else {
            Print(L"Invalid. Try M, R, or Q: ");
        }
    }
    
    Print(L"\nReturning to firmware...\n");
    
    // Cleanup
    if (gVariables) {
        FreePool(gVariables);
    }
    
    return EFI_SUCCESS;
}
