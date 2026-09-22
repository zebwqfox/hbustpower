"""把备案材料中的隐私政策与用户协议同步到 App 资源，并生成可托管的 HTML。

单一来源是 filing/ 下的 Markdown；改完执行：

    python android/tools/sync-legal.py

会更新：
  android/app/src/main/assets/legal/*.md   应用内"隐私政策""用户协议"页面读取的文本
  filing/html/*.html                           备案与应用商店要求的公开网页版本
"""

from __future__ import annotations

import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCUMENTS = [
    ("03-隐私政策.md", "privacy.md", "privacy-policy.html", "湖科电量 隐私政策"),
    ("04-用户协议.md", "agreement.md", "user-agreement.html", "湖科电量 用户服务协议"),
]

STYLE = """
:root { color-scheme: light dark; --text: #111318; --muted: #6e7380; --accent: #1f57c2; --line: #e3e7ef; --bg: #f6f9fe; --card: #ffffff; }
@media (prefers-color-scheme: dark) { :root { --text: #f2f6ff; --muted: #a9b1c0; --accent: #85b8ff; --line: #24304a; --bg: #0a0f1a; --card: #141c2b; } }
* { box-sizing: border-box; }
body { margin: 0; padding: 32px 16px 64px; background: var(--bg); color: var(--text);
       font: 16px/1.75 -apple-system, "PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", sans-serif; }
main { max-width: 720px; margin: 0 auto; background: var(--card); border-radius: 20px; padding: 32px 28px; }
h1 { font-size: 26px; margin: 0 0 4px; }
h2 { font-size: 19px; margin: 32px 0 8px; }
p, li { color: var(--text); }
em.meta { display: block; color: var(--muted); font-style: normal; font-size: 14px; }
table { width: 100%; border-collapse: collapse; margin: 12px 0; font-size: 15px; }
th, td { border: 1px solid var(--line); padding: 8px 10px; text-align: left; vertical-align: top; }
th { background: color-mix(in srgb, var(--accent) 8%, transparent); }
strong { color: var(--accent); }
footer { max-width: 720px; margin: 16px auto 0; color: var(--muted); font-size: 13px; }
"""


def inline(text: str) -> str:
    escaped = html.escape(text)
    escaped = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", escaped)
    escaped = re.sub(r"`(.+?)`", r"<code>\1</code>", escaped)
    return escaped


def to_html(markdown: str, title: str) -> str:
    body: list[str] = []
    table: list[list[str]] = []
    bullets: list[str] = []

    def flush() -> None:
        if bullets:
            body.append("<ul>" + "".join(f"<li>{inline(item)}</li>" for item in bullets) + "</ul>")
            bullets.clear()
        if table:
            header, *rows = [row for row in table if not all(set(cell) <= set("-: ") for cell in row)]
            cells = "".join(f"<th>{inline(cell)}</th>" for cell in header)
            body.append("<table><thead><tr>" + cells + "</tr></thead><tbody>")
            for row in rows:
                body.append("<tr>" + "".join(f"<td>{inline(cell)}</td>" for cell in row) + "</tr>")
            body.append("</tbody></table>")
            table.clear()

    for line in markdown.splitlines():
        stripped = line.strip()
        if not stripped:
            flush()
            continue
        if stripped.startswith("|"):
            table.append([cell.strip() for cell in stripped.strip("|").split("|")])
            continue
        flush()
        if stripped.startswith("## "):
            body.append(f"<h2>{inline(stripped[3:])}</h2>")
        elif stripped.startswith("# "):
            body.append(f"<h1>{inline(stripped[2:])}</h1>")
        elif stripped.startswith("- "):
            bullets.append(stripped[2:])
        elif stripped.startswith("生效日期") or stripped.startswith("版本"):
            body.append(f'<em class="meta">{inline(stripped)}</em>')
        else:
            body.append(f"<p>{inline(stripped)}</p>")
    flush()

    return (
        "<!doctype html>\n<html lang=\"zh-CN\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        f"<title>{html.escape(title)}</title>\n<style>{STYLE}</style>\n</head>\n<body>\n<main>\n"
        + "\n".join(body)
        + "\n</main>\n<footer>本页面由 android/tools/sync-legal.py 从备案材料生成，请勿直接编辑。</footer>\n</body>\n</html>\n"
    )


def main() -> None:
    assets = ROOT / "android/app/src/main/assets/legal"
    pages = ROOT / "filing/html"
    assets.mkdir(parents=True, exist_ok=True)
    pages.mkdir(parents=True, exist_ok=True)

    for source_name, asset_name, page_name, title in DOCUMENTS:
        source = (ROOT / "filing" / source_name).read_text(encoding="utf-8")
        # 应用内页面不显示 HTML 注释形式的填写提示。
        in_app = re.sub(r"<!--.*?-->", "（见应用商店页面）", source, flags=re.S)
        (assets / asset_name).write_text(in_app, encoding="utf-8")
        (pages / page_name).write_text(to_html(source, title), encoding="utf-8")
        print(f"{source_name} -> assets/legal/{asset_name}, filing/html/{page_name}")


if __name__ == "__main__":
    main()
