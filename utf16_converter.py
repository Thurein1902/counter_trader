import json
import os
import re

def clean_json_content(content):
    """Clean and normalize JSON content"""
    # Remove UTF-8 BOM if present
    if content.startswith('\ufeff'):
        content = content[1:]
    
    # Remove any other BOMs
    content = content.lstrip('\ufeff\ufffe\u0000')
    
    # Strip whitespace
    content = content.strip()
    
    return content

def try_multiple_encodings(file_path):
    """Try multiple encoding methods to read the file"""
    encodings = [
        'utf-16-le',
        'utf-16-be', 
        'utf-16',
        'utf-8-sig',
        'utf-8',
        'cp1252',
        'latin-1'
    ]
    
    for encoding in encodings:
        try:
            print(f"Trying encoding: {encoding}")
            with open(file_path, 'r', encoding=encoding) as f:
                content = f.read()
            
            # Clean the content
            content = clean_json_content(content)
            
            if content:
                # Try to parse as JSON
                data = json.loads(content)
                print(f"Success with encoding: {encoding}")
                return data, content
                
        except (UnicodeDecodeError, json.JSONDecodeError) as e:
            print(f"Failed with {encoding}: {e}")
            continue
        except Exception as e:
            print(f"Error with {encoding}: {e}")
            continue
    
    return None, None

def convert_file():
    """Convert the JSON file to proper UTF-8"""
    source_file = "fx_signals.json"
    
    if not os.path.exists(source_file):
        print(f"File not found: {source_file}")
        return False
    
    # Create backup
    backup_file = source_file + ".backup"
    import shutil
    shutil.copy2(source_file, backup_file)
    print(f"Backup created: {backup_file}")
    
    # Try to read with multiple encodings
    data, content = try_multiple_encodings(source_file)
    
    if data is None:
        print("Failed to read file with any encoding")
        return False
    
    # Validate structure
    if 'forexData' not in data:
        print("Invalid JSON structure - missing 'forexData'")
        return False
    
    pairs_count = len(data['forexData'])
    print(f"Found {pairs_count} currency pairs")
    
    # Show sample data
    sample_pairs = list(data['forexData'].items())[:3]
    for pair, pair_data in sample_pairs:
        confidence = pair_data.get('Confidence', 'N/A')
        overall = pair_data.get('Overall_Ranking', 'N/A')
        print(f"  {pair}: Confidence={confidence}%, Ranking={overall}")
    
    # Write as clean UTF-8
    try:
        with open(source_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"Successfully converted {source_file} to UTF-8")
        return True
    except Exception as e:
        print(f"Error writing UTF-8 file: {e}")
        return False

def test_website_compatibility():
    """Test if the converted file works with the website"""
    try:
        with open("fx_signals.json", 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        print("\nWebsite compatibility test:")
        print("✅ File reads correctly as UTF-8")
        print("✅ Valid JSON format")
        
        if 'forexData' in data:
            print("✅ Contains forexData structure")
            
            # Check required fields
            sample_pair = next(iter(data['forexData'].values()))
            required_fields = [
                'Currency_Strength_Rank_all_pair',
                'CCI_Currency_Strength_Rank_all_pair',
                'BB_percent_ranking',
                'RSI_breakout',
                'Overall_Ranking',
                'Confidence'
            ]
            
            missing_fields = [field for field in required_fields if field not in sample_pair]
            if missing_fields:
                print(f"❌ Missing fields: {missing_fields}")
            else:
                print("✅ All required fields present")
                
        return True
        
    except Exception as e:
        print(f"❌ Website compatibility test failed: {e}")
        return False

if __name__ == "__main__":
    print("=== Robust JSON File Converter ===\n")
    
    if convert_file():
        print("\n" + "="*50)
        test_website_compatibility()
        print("\n" + "="*50)
        print("\nNow you can:")
        print("1. Test your website by opening index.html")
        print("2. Update your file_updater.py with the new encoding-aware function")
        print("3. Start a local server: python -m http.server 8000")
    else:
        print("\nConversion failed. Check the error messages above.")