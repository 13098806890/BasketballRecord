import json
import os
import subprocess
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
from urllib.request import Request, urlopen
from urllib.error import URLError

CONFIG_FILE = os.path.join(os.path.dirname(__file__), ".deploy_config.json")
METADATA_DIR = os.path.join(os.path.dirname(__file__), "metadata")

LOCALES = [
    ("en-US", "English"),
    ("zh-Hans", "简体中文"),
    ("zh-Hant", "繁體中文"),
    ("ja", "日本語"),
    ("ko", "한국어"),
    ("de-DE", "Deutsch"),
    ("es-ES", "Español"),
    ("fr-FR", "Français"),
    ("it", "Italiano"),
    ("ru", "Русский"),
]

SOURCE_LANG = "zh-Hans"
TARGET_LOCALES = [l for l in LOCALES if l[0] != SOURCE_LANG]


def load_config():
    if not os.path.exists(CONFIG_FILE):
        return {}
    with open(CONFIG_FILE, "r") as f:
        return json.load(f)


def save_config(cfg):
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=2)


def call_deepseek(api_key, prompt):
    url = "https://api.deepseek.com/v1/chat/completions"
    body = json.dumps({
        "model": "deepseek-chat",
        "messages": [
            {"role": "system", "content": "You are a professional translator for App Store metadata. Translate the given text into the target language. Return ONLY the translated text, no explanation, no quotes."},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.3,
        "max_tokens": 2000
    }).encode()

    req = Request(url, data=body, headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    })

    try:
        resp = urlopen(req, timeout=30)
        data = json.loads(resp.read())
        return data["choices"][0]["message"]["content"].strip()
    except URLError as e:
        return f"[API Error] {e.reason}"
    except Exception as e:
        return f"[Error] {e}"


def translate_text(api_key, source_text, target_lang, target_label):
    if not source_text.strip():
        return ""
    prompt = f"Translate the following App Store text from Chinese to {target_label}. Preserve the meaning exactly, adapt to natural {target_label} App Store style:\n\n{source_text}"
    return call_deepseek(api_key, prompt)


class DeployTool(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("BasketballRecord 发布工具")
        self.geometry("800x750")
        self.config = load_config()

        notebook = ttk.Notebook(self)
        notebook.pack(fill="both", expand=True, padx=10, pady=10)

        setup_frame = ttk.Frame(notebook)
        translate_frame = ttk.Frame(notebook)
        publish_frame = ttk.Frame(notebook)

        notebook.add(setup_frame, text="设置")
        notebook.add(translate_frame, text="翻译")
        notebook.add(publish_frame, text="发布")

        self._build_setup(setup_frame)
        self._build_translate(translate_frame)
        self._build_publish(publish_frame)

    def _build_setup(self, parent):
        frame = ttk.Frame(parent, padding=20)
        frame.pack(fill="both", expand=True)

        ttk.Label(frame, text="DeepSeek API Key", font=("", 12)).pack(anchor="w")
        self.api_key_var = tk.StringVar(value=self.config.get("api_key", ""))
        ttk.Entry(frame, textvariable=self.api_key_var, width=60, show="*").pack(fill="x", pady=(4, 20))

        ttk.Label(frame, text="Apple ID (App Store Connect)", font=("", 12)).pack(anchor="w")
        self.apple_id_var = tk.StringVar(value=self.config.get("apple_id", ""))
        ttk.Entry(frame, textvariable=self.apple_id_var, width=60).pack(fill="x", pady=(4, 20))

        ttk.Label(frame, text="App Version (如 1.15)", font=("", 12)).pack(anchor="w")
        self.version_var = tk.StringVar(value=self.config.get("version", "1.15"))
        ttk.Entry(frame, textvariable=self.version_var, width=20).pack(anchor="w", pady=(4, 20))

        def save():
            self.config["api_key"] = self.api_key_var.get()
            self.config["apple_id"] = self.apple_id_var.get()
            self.config["version"] = self.version_var.get()
            save_config(self.config)
            messagebox.showinfo("成功", "配置已保存")

        ttk.Button(frame, text="保存配置", command=save).pack()

    def _build_translate(self, parent):
        frame = ttk.Frame(parent, padding=20)
        frame.pack(fill="both", expand=True)

        ttk.Label(frame, text="Promotional Text (中文)", font=("", 12)).pack(anchor="w")
        self.promo_cn = scrolledtext.ScrolledText(frame, height=4)
        self.promo_cn.pack(fill="x", pady=(4, 10))

        ttk.Label(frame, text="What's New (中文)", font=("", 12)).pack(anchor="w")
        self.notes_cn = scrolledtext.ScrolledText(frame, height=3)
        self.notes_cn.pack(fill="x", pady=(4, 10))

        btn_frame = ttk.Frame(frame)
        btn_frame.pack(fill="x", pady=10)
        ttk.Button(btn_frame, text="翻译到其他 9 种语言", command=self._do_translate).pack(side="left")
        self.translate_status = ttk.Label(btn_frame, text="", foreground="blue")
        self.translate_status.pack(side="left", padx=10)

        ttk.Label(frame, text="翻译结果预览", font=("", 12)).pack(anchor="w")
        self.preview = scrolledtext.ScrolledText(frame, height=20)
        self.preview.pack(fill="both", expand=True, pady=(4, 0))

        self._translated = {}

    def _do_translate(self):
        api_key = self.api_key_var.get()
        if not api_key:
            messagebox.showerror("错误", "请先在「设置」页填写 DeepSeek API Key")
            return

        promo = self.promo_cn.get("1.0", tk.END).strip()
        notes = self.notes_cn.get("1.0", tk.END).strip()
        if not promo and not notes:
            messagebox.showwarning("警告", "请至少填写一项中文内容")
            return

        self.translate_status.config(text="翻译中...")
        self.update()

        results = {}
        results[SOURCE_LANG] = {"promotional_text": promo, "release_notes": notes}

        for code, label in TARGET_LOCALES:
            self.translate_status.config(text=f"翻译 {label}...")
            self.update()

            p = translate_text(api_key, promo, code, label) if promo else ""
            n = translate_text(api_key, notes, code, label) if notes else ""
            results[code] = {"promotional_text": p, "release_notes": n}

        self._translated = results
        self._show_preview()
        self.translate_status.config(text="翻译完成 ✓", foreground="green")

    def _show_preview(self):
        self.preview.delete("1.0", tk.END)
        for code, label in LOCALES:
            data = self._translated.get(code, {})
            p = data.get("promotional_text", "")
            n = data.get("release_notes", "")
            self.preview.insert(tk.END, f"--- {label} ({code}) ---\n")
            self.preview.insert(tk.END, f"Promo: {p}\n")
            self.preview.insert(tk.END, f"What's New: {n}\n\n")

    def _build_publish(self, parent):
        frame = ttk.Frame(parent, padding=20)
        frame.pack(fill="both", expand=True)

        ttk.Label(frame, text="发布前请确认：", font=("", 13, "bold")).pack(anchor="w")
        ttk.Label(frame, text="1. 已在「设置」页配置 DeepSeek API Key 和 Apple ID").pack(anchor="w", pady=2)
        ttk.Label(frame, text="2. 已在「翻译」页完成内容填写和翻译").pack(anchor="w", pady=2)
        ttk.Label(frame, text="3. Fastlane 已安装 (gem install fastlane)").pack(anchor="w", pady=2)
        ttk.Label(frame, text="4. 首次使用前运行 fastlane spaceauth 完成 Apple ID 认证").pack(anchor="w", pady=2)

        btn_frame = ttk.Frame(frame)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="写入元数据文件并发布", command=self._do_publish, width=30).pack()

        self.publish_log = scrolledtext.ScrolledText(frame, height=20)
        self.publish_log.pack(fill="both", expand=True, pady=(10, 0))

    def _log(self, msg):
        self.publish_log.insert(tk.END, msg + "\n")
        self.publish_log.see(tk.END)
        self.update()

    def _do_publish(self):
        if not self._translated:
            messagebox.showerror("错误", "请先在「翻译」页完成翻译")
            return

        apple_id = self.apple_id_var.get()
        if not apple_id:
            messagebox.showerror("错误", "请先在「设置」页填写 Apple ID")
            return

        version = self.version_var.get()

        # Update Appfile
        appfile_path = os.path.join(os.path.dirname(__file__), "Appfile")
        with open(appfile_path, "w") as f:
            f.write(f'app_identifier("com.xiedongze.BasketballRecord")\n')
            f.write(f'apple_id("{apple_id}")\n')

        # Write metadata files
        for code, data in self._translated.items():
            locale_dir = os.path.join(METADATA_DIR, code)
            os.makedirs(locale_dir, exist_ok=True)

            for key in ("promotional_text", "release_notes"):
                text = data.get(key, "")
                file_path = os.path.join(locale_dir, f"{key}.txt")
                with open(file_path, "w") as f:
                    f.write(text)
                self._log(f"  ✓ {code}/{key}.txt")

        self._log("\n元数据文件写入完成。正在调用 Fastlane...\n")

        # Run fastlane
        try:
            result = subprocess.run(
                ["fastlane", "ios", "upload_metadata"],
                cwd=os.path.dirname(__file__),
                capture_output=True,
                text=True,
                timeout=300,
            )
            self._log(result.stdout)
            if result.stderr:
                self._log(f"STDERR: {result.stderr}")
            if result.returncode == 0:
                self._log("\n✅ 发布成功！")
                messagebox.showinfo("成功", "元数据已上传到 App Store Connect")
            else:
                self._log(f"\n❌ Fastlane 返回错误码 {result.returncode}")
                messagebox.showerror("失败", f"Fastlane 执行失败，请查看日志")
        except FileNotFoundError:
            self._log("\n❌ Fastlane 未安装。请运行: sudo gem install fastlane")
            self._log("安装后首次使用还需运行: fastlane spaceauth")
            messagebox.showerror("失败", "Fastlane 未安装，请先运行 sudo gem install fastlane")
        except subprocess.TimeoutExpired:
            self._log("\n❌ Fastlane 执行超时")
            messagebox.showerror("失败", "Fastlane 执行超时")
        except Exception as e:
            self._log(f"\n❌ 错误: {e}")
            messagebox.showerror("失败", str(e))


if __name__ == "__main__":
    app = DeployTool()
    app.mainloop()
