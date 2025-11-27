#!/usr/bin/env python3
"""
PhoenixBoot Firmware Checksum Database
======================================

Manages and verifies firmware checksums against known-good values.
Supports automated firmware verification and bootkit detection.

Requirements: Python 3.8+ (uses walrus operator)

Usage:
    python3 firmware_checksum_db.py --verify /path/to/firmware.bin
    python3 firmware_checksum_db.py --add /path/to/firmware.bin --vendor ASUS --model "ROG X570"
    python3 firmware_checksum_db.py --list
"""

import os
import sys
import json
import hashlib
import sqlite3
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime
import argparse


@dataclass
class FirmwareEntry:
    """Represents a firmware entry in the database"""
    vendor: str
    model: str
    version: str
    sha256: str
    sha1: str
    md5: str
    size: int
    source: str
    confidence_score: int
    added_date: str
    notes: str = ""


class FirmwareChecksumDB:
    """Database for storing and verifying firmware checksums"""
    
    def __init__(self, db_path: Optional[str] = None):
        """Initialize the firmware checksum database"""
        if db_path is None:
            # Use default path in repository
            repo_root = Path(__file__).parent.parent
            db_path = repo_root / "out" / "firmware_checksums.db"
            db_path.parent.mkdir(parents=True, exist_ok=True)
        
        self.db_path = Path(db_path)
        self._init_database()
    
    def _init_database(self):
        """Initialize the SQLite database schema"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Create firmware_checksums table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS firmware_checksums (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vendor TEXT NOT NULL,
                model TEXT NOT NULL,
                version TEXT NOT NULL,
                sha256 TEXT UNIQUE NOT NULL,
                sha1 TEXT NOT NULL,
                md5 TEXT NOT NULL,
                size INTEGER NOT NULL,
                source TEXT NOT NULL,
                confidence_score INTEGER DEFAULT 50,
                added_date TEXT NOT NULL,
                notes TEXT,
                UNIQUE(vendor, model, version)
            )
        """)
        
        # Create index for faster lookups
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_sha256 ON firmware_checksums(sha256)
        """)
        
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_vendor_model ON firmware_checksums(vendor, model)
        """)
        
        conn.commit()
        conn.close()
    
    def calculate_checksums(self, firmware_path: Path) -> Dict[str, str]:
        """Calculate SHA256, SHA1, and MD5 checksums for a firmware file"""
        sha256_hash = hashlib.sha256()
        sha1_hash = hashlib.sha1()
        md5_hash = hashlib.md5()
        
        with open(firmware_path, 'rb') as f:
            while chunk := f.read(65536):  # 64KB chunks
                sha256_hash.update(chunk)
                sha1_hash.update(chunk)
                md5_hash.update(chunk)
        
        return {
            'sha256': sha256_hash.hexdigest(),
            'sha1': sha1_hash.hexdigest(),
            'md5': md5_hash.hexdigest(),
            'size': firmware_path.stat().st_size
        }
    
    def add_firmware(self, firmware_path: Path, vendor: str, model: str, 
                     version: str, source: str = "manual", 
                     confidence_score: int = 50, notes: str = "") -> bool:
        """Add a firmware entry to the database"""
        try:
            # Calculate checksums
            checksums = self.calculate_checksums(firmware_path)
            
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute("""
                INSERT OR REPLACE INTO firmware_checksums 
                (vendor, model, version, sha256, sha1, md5, size, source, 
                 confidence_score, added_date, notes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                vendor, model, version,
                checksums['sha256'], checksums['sha1'], checksums['md5'],
                checksums['size'], source, confidence_score,
                datetime.now().isoformat(), notes
            ))
            
            conn.commit()
            conn.close()
            
            print(f"✓ Added firmware: {vendor} {model} {version}")
            print(f"  SHA256: {checksums['sha256']}")
            return True
            
        except Exception as e:
            print(f"✗ Error adding firmware: {e}", file=sys.stderr)
            return False
    
    def verify_firmware(self, firmware_path: Path) -> Tuple[bool, Optional[FirmwareEntry]]:
        """Verify a firmware file against the database"""
        try:
            # Calculate checksums of the file
            checksums = self.calculate_checksums(firmware_path)
            
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Look up by SHA256 (most secure)
            cursor.execute("""
                SELECT * FROM firmware_checksums WHERE sha256 = ?
            """, (checksums['sha256'],))
            
            result = cursor.fetchone()
            conn.close()
            
            if result:
                # Convert to FirmwareEntry
                entry = FirmwareEntry(
                    vendor=result[1],
                    model=result[2],
                    version=result[3],
                    sha256=result[4],
                    sha1=result[5],
                    md5=result[6],
                    size=result[7],
                    source=result[8],
                    confidence_score=result[9],
                    added_date=result[10],
                    notes=result[11] or ""
                )
                return True, entry
            else:
                return False, None
                
        except Exception as e:
            print(f"✗ Error verifying firmware: {e}", file=sys.stderr)
            return False, None
    
    def search_firmware(self, vendor: Optional[str] = None, 
                       model: Optional[str] = None) -> List[FirmwareEntry]:
        """Search for firmware entries by vendor and/or model"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        query = "SELECT * FROM firmware_checksums WHERE 1=1"
        params = []
        
        if vendor:
            query += " AND vendor LIKE ?"
            params.append(f"%{vendor}%")
        
        if model:
            query += " AND model LIKE ?"
            params.append(f"%{model}%")
        
        cursor.execute(query, params)
        results = cursor.fetchall()
        conn.close()
        
        entries = []
        for result in results:
            entry = FirmwareEntry(
                vendor=result[1],
                model=result[2],
                version=result[3],
                sha256=result[4],
                sha1=result[5],
                md5=result[6],
                size=result[7],
                source=result[8],
                confidence_score=result[9],
                added_date=result[10],
                notes=result[11] or ""
            )
            entries.append(entry)
        
        return entries
    
    def list_all_firmware(self) -> List[FirmwareEntry]:
        """List all firmware entries in the database"""
        return self.search_firmware()
    
    def export_to_json(self, output_path: Path):
        """Export the database to JSON format"""
        entries = self.list_all_firmware()
        data = [asdict(entry) for entry in entries]
        
        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
        
        print(f"✓ Exported {len(entries)} entries to {output_path}")
    
    def import_from_json(self, input_path: Path):
        """Import firmware entries from JSON file"""
        with open(input_path, 'r') as f:
            data = json.load(f)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        imported = 0
        for entry in data:
            try:
                cursor.execute("""
                    INSERT OR IGNORE INTO firmware_checksums 
                    (vendor, model, version, sha256, sha1, md5, size, source, 
                     confidence_score, added_date, notes)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    entry['vendor'], entry['model'], entry['version'],
                    entry['sha256'], entry['sha1'], entry['md5'],
                    entry['size'], entry['source'], entry['confidence_score'],
                    entry['added_date'], entry.get('notes', '')
                ))
                imported += 1
            except Exception as e:
                print(f"⚠ Error importing entry: {e}", file=sys.stderr)
        
        conn.commit()
        conn.close()
        
        print(f"✓ Imported {imported} firmware entries")


def main():
    """Main entry point for CLI usage"""
    parser = argparse.ArgumentParser(
        description="PhoenixBoot Firmware Checksum Database Manager"
    )
    
    parser.add_argument('--db', type=str, 
                       help='Path to database file (default: out/firmware_checksums.db)')
    
    # Operations
    parser.add_argument('--verify', type=str, metavar='FILE',
                       help='Verify a firmware file against the database')
    parser.add_argument('--add', type=str, metavar='FILE',
                       help='Add a firmware file to the database')
    parser.add_argument('--list', action='store_true',
                       help='List all firmware entries')
    parser.add_argument('--search', action='store_true',
                       help='Search for firmware by vendor/model')
    parser.add_argument('--export', type=str, metavar='FILE',
                       help='Export database to JSON')
    parser.add_argument('--import', type=str, metavar='FILE', dest='import_file',
                       help='Import firmware entries from JSON')
    
    # Metadata for --add
    parser.add_argument('--vendor', type=str, help='Firmware vendor')
    parser.add_argument('--model', type=str, help='Firmware model')
    parser.add_argument('--version', type=str, help='Firmware version')
    parser.add_argument('--source', type=str, default='manual',
                       help='Source of firmware (default: manual)')
    parser.add_argument('--confidence', type=int, default=50,
                       help='Confidence score 0-100 (default: 50)')
    parser.add_argument('--notes', type=str, default='',
                       help='Additional notes')
    
    args = parser.parse_args()
    
    # Initialize database
    db = FirmwareChecksumDB(args.db)
    
    # Execute operations
    if args.verify:
        firmware_path = Path(args.verify)
        if not firmware_path.exists():
            print(f"✗ File not found: {firmware_path}", file=sys.stderr)
            return 1
        
        verified, entry = db.verify_firmware(firmware_path)
        if verified and entry:
            print(f"✓ VERIFIED: Firmware matches known-good checksum")
            print(f"  Vendor:     {entry.vendor}")
            print(f"  Model:      {entry.model}")
            print(f"  Version:    {entry.version}")
            print(f"  Confidence: {entry.confidence_score}/100")
            print(f"  Source:     {entry.source}")
            if entry.notes:
                print(f"  Notes:      {entry.notes}")
            return 0
        else:
            print(f"✗ UNVERIFIED: Firmware checksum not found in database")
            print(f"  This firmware may be:")
            print(f"    - A new/unknown version")
            print(f"    - Modified or compromised")
            print(f"    - From an untrusted source")
            print(f"\n  SHA256: {db.calculate_checksums(firmware_path)['sha256']}")
            return 1
    
    elif args.add:
        firmware_path = Path(args.add)
        if not firmware_path.exists():
            print(f"✗ File not found: {firmware_path}", file=sys.stderr)
            return 1
        
        if not all([args.vendor, args.model, args.version]):
            print("✗ Error: --vendor, --model, and --version are required for --add",
                  file=sys.stderr)
            return 1
        
        success = db.add_firmware(
            firmware_path, args.vendor, args.model, args.version,
            args.source, args.confidence, args.notes
        )
        return 0 if success else 1
    
    elif args.list:
        entries = db.list_all_firmware()
        if not entries:
            print("No firmware entries in database")
            return 0
        
        print(f"Firmware Checksums Database ({len(entries)} entries)")
        print("=" * 80)
        for entry in entries:
            print(f"\n{entry.vendor} {entry.model} v{entry.version}")
            print(f"  SHA256:     {entry.sha256}")
            print(f"  Size:       {entry.size:,} bytes")
            print(f"  Confidence: {entry.confidence_score}/100")
            print(f"  Source:     {entry.source}")
            if entry.notes:
                print(f"  Notes:      {entry.notes}")
        return 0
    
    elif args.search:
        entries = db.search_firmware(args.vendor, args.model)
        if not entries:
            print("No matching firmware found")
            return 0
        
        print(f"Found {len(entries)} matching firmware entries")
        print("=" * 80)
        for entry in entries:
            print(f"\n{entry.vendor} {entry.model} v{entry.version}")
            print(f"  SHA256: {entry.sha256[:32]}...")
            print(f"  Confidence: {entry.confidence_score}/100")
        return 0
    
    elif args.export:
        db.export_to_json(Path(args.export))
        return 0
    
    elif args.import_file:
        db.import_from_json(Path(args.import_file))
        return 0
    
    else:
        parser.print_help()
        return 0


if __name__ == '__main__':
    sys.exit(main())
