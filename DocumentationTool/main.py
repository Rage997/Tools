import re
from pathlib import Path
from ollama import generate

def generate_description(class_name: str, model: str = "gemma3:latest") -> str:
    """
    Uses Ollama to generate a single-paragraph description formatted to be inserted
    directly under a Lua class heading in RST files.
    """
    prompt = (
        f'Write a concise, **single-paragraph** description for the Lua class "{class_name}". '
        f'The output should NOT include any comments, code blocks, or explanations. '
        f'It should start immediately after the heading and flow naturally in one paragraph. '
        f'The description should be informative about its purpose and typical usage.'
    )
    try:
        response = generate(model=model, prompt=prompt)
        return response['response'].strip()
    except Exception as e:
        print("Error generating description:", e)
        return ""
def add_description_to_file(file_path: str, model: str = "gemma3:latest"):
    path = Path(file_path)
    content = path.read_text(encoding="utf-8")

    match = re.search(r"^(\w+)\n=+\n", content, re.MULTILINE)
    if not match:
        print("No heading found in the file.")
        return

    class_name = match.group(1)
    heading_end_index = match.end()

    after_heading = content[heading_end_index:].lstrip()
    if after_heading.startswith("A ") or after_heading.startswith(class_name):
        print("Description already exists. Skipping.")
        return

    description = generate_description(class_name, model)
    if not description:
        print("No description generated.")
        return

    new_content = content[:heading_end_index] + "\n" + description + "\n" + content[heading_end_index:]
    path.write_text(new_content, encoding="utf-8")
    print(f"Description added to {file_path}")

if __name__ == "__main__":
    add_description_to_file(
        "your file"
    )
