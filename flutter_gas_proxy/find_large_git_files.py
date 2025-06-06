import subprocess
import sys

def find_large_git_files(top_n=20):
    print("Starting to list Git objects... This may take a while for large repositories.")
    try:
        # Get all object hashes and paths
        # Use 'git.exe' for robustness on Windows
        result = subprocess.run(
            ['git.exe', 'rev-list', '--all', '--objects'],
            capture_output=True,
            text=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Error running git rev-list: {e}")
        print(f"Stderr: {e.stderr}")
        return []

    lines = result.stdout.strip().split('\n')
    if not lines:
        print("No Git objects found.")
        return []

    # List to store (size, hash, path)
    object_sizes = []

    # Iterate through each object to get its size
    total_objects = len(lines)
    print(f"Found {total_objects} objects. Getting sizes (this might take a while)...")

    for i, line in enumerate(lines):
        parts = line.split(' ', 1)
        if len(parts) < 1:
            continue # Skip malformed lines

        obj_hash = parts[0]
        obj_path = parts[1] if len(parts) > 1 else ''

        # Progress indicator
        if (i + 1) % 1000 == 0 or (i + 1) == total_objects:
            print(f"Processing object {i + 1}/{total_objects}...", end='\r', flush=True)

        try:
            size_result = subprocess.run(
                ['git.exe', 'cat-file', '-s', obj_hash],
                capture_output=True,
                text=True,
                check=True
            )
            size_bytes = int(size_result.stdout.strip())
            object_sizes.append((size_bytes, obj_hash, obj_path))
        except (subprocess.CalledProcessError, ValueError) as e:
            # print(f"Warning: Could not get size for {obj_hash}: {e}", file=sys.stderr)
            continue

    print("\nSorting results...")
    # Sort by size in descending order
    object_sizes.sort(key=lambda x: x[0], reverse=True)

    print("\n--- Top Large Git Objects ---")
    formatted_results = []
    for i, (size, obj_hash, obj_path) in enumerate(object_sizes[:top_n]):
        # Convert bytes to human-readable format
        def human_readable_size(size_bytes):
            if size_bytes < 1024:
                return f"{size_bytes} B"
            elif size_bytes < 1024**2:
                return f"{size_bytes / 1024:.2f} KB"
            elif size_bytes < 1024**3:
                return f"{size_bytes / (1024**2):.2f} MB"
            else:
                return f"{size_bytes / (1024**3):.2f} GB"

        formatted_line = f"{human_readable_size(size)} ({size} B) {obj_hash} {obj_path}"
        formatted_results.append(formatted_line)
        print(formatted_line)
    return formatted_results

if __name__ == "__main__":
    find_large_git_files()