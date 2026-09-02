#!/usr/bin/env python3
"""project.pbxproj için küçük bir doğrulayıcı.

pbxproj eski tip (OpenStep) ASCII plist'tir; plistlib okumaz. Burada
sadece yapıyı doğrulayacak kadar ayrıştırıyoruz:
  - parantez/süslü parantez dengesi ve her girdinin ; ile bitmesi
  - nesne kimliklerinin 24 karakter olması
  - her referansın tanımlı bir nesneye gitmesi, her nesnenin kullanılması
  - hedeflerin build phase / configuration list bağlarının tutması
"""

import re
import sys
from pathlib import Path


class Parser:
    def __init__(self, text):
        # Yorumları at (/* ... */), dizge içindekilere dokunmuyoruz çünkü
        # pbxproj'de dizge içinde /* geçmiyor.
        self.text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
        self.i = 0

    def skip(self):
        while self.i < len(self.text) and self.text[self.i] in " \t\r\n":
            self.i += 1

    def parse_value(self):
        self.skip()
        ch = self.text[self.i]
        if ch == "{":
            return self.parse_dict()
        if ch == "(":
            return self.parse_array()
        if ch == '"':
            return self.parse_quoted()
        return self.parse_bare()

    def parse_dict(self):
        assert self.text[self.i] == "{"
        self.i += 1
        out = {}
        while True:
            self.skip()
            if self.i >= len(self.text):
                raise SyntaxError("dosya sözlük içinde bitti")
            if self.text[self.i] == "}":
                self.i += 1
                return out
            key = self.parse_value()
            self.skip()
            if self.text[self.i] != "=":
                raise SyntaxError(f"{key!r} sonrası '=' bekleniyordu, konum {self.i}")
            self.i += 1
            value = self.parse_value()
            self.skip()
            if self.text[self.i] != ";":
                raise SyntaxError(f"{key!r} girdisi ';' ile bitmiyor, konum {self.i}")
            self.i += 1
            out[key] = value

    def parse_array(self):
        assert self.text[self.i] == "("
        self.i += 1
        out = []
        while True:
            self.skip()
            if self.text[self.i] == ")":
                self.i += 1
                return out
            out.append(self.parse_value())
            self.skip()
            if self.text[self.i] == ",":
                self.i += 1
            elif self.text[self.i] != ")":
                raise SyntaxError(f"dizide ',' ya da ')' bekleniyordu, konum {self.i}")

    def parse_quoted(self):
        self.i += 1
        out = []
        while self.text[self.i] != '"':
            if self.text[self.i] == "\\":
                out.append(self.text[self.i + 1])
                self.i += 2
                continue
            out.append(self.text[self.i])
            self.i += 1
        self.i += 1
        return "".join(out)

    def parse_bare(self):
        start = self.i
        while self.text[self.i] not in " \t\r\n;,=(){}":
            self.i += 1
        if start == self.i:
            raise SyntaxError(f"boş belirteç, konum {self.i}")
        return self.text[start:self.i]


def main(path):
    raw = Path(path).read_text()
    if not raw.startswith("// !$*UTF8*$!"):
        return ["dosya '// !$*UTF8*$!' başlığıyla başlamıyor"]

    parser = Parser(raw[raw.index("{"):])
    root = parser.parse_dict()

    problems = []
    objects = root.get("objects")
    if not isinstance(objects, dict):
        return ["objects sözlüğü yok"]

    ids = set(objects)
    for oid, obj in objects.items():
        if len(oid) != 24:
            problems.append(f"kimlik 24 karakter değil: {oid}")
        if not isinstance(obj, dict) or "isa" not in obj:
            problems.append(f"{oid}: isa yok")

    referenced = set()

    def walk(value):
        if isinstance(value, dict):
            for k, v in value.items():
                if k in ids:
                    referenced.add(k)
                walk(v)
        elif isinstance(value, list):
            for v in value:
                walk(v)
        elif isinstance(value, str) and value in ids:
            referenced.add(value)

    for oid, obj in objects.items():
        walk(obj)
    root_object = root.get("rootObject")
    if root_object in ids:
        referenced.add(root_object)
    else:
        problems.append(f"rootObject tanımsız: {root_object}")

    for orphan in sorted(ids - referenced):
        problems.append(f"hiçbir yerden referans verilmeyen nesne: {orphan} ({objects[orphan].get('isa')})")

    # Hedef bağlarını doğrula
    for oid, obj in objects.items():
        if obj.get("isa") != "PBXNativeTarget":
            continue
        for phase in obj.get("buildPhases", []):
            if phase not in ids:
                problems.append(f"{obj.get('name')}: build phase tanımsız {phase}")
        clist = obj.get("buildConfigurationList")
        if clist not in ids:
            problems.append(f"{obj.get('name')}: configuration list tanımsız")
        else:
            for cfg in objects[clist].get("buildConfigurations", []):
                if cfg not in ids:
                    problems.append(f"{obj.get('name')}: build configuration tanımsız {cfg}")
        for group in obj.get("fileSystemSynchronizedGroups", []):
            if objects.get(group, {}).get("isa") != "PBXFileSystemSynchronizedRootGroup":
                problems.append(f"{obj.get('name')}: senkron klasör grubu geçersiz {group}")

    counts = {}
    for obj in objects.values():
        counts[obj.get("isa")] = counts.get(obj.get("isa"), 0) + 1
    print("nesne sayısı:", len(objects))
    for isa in sorted(counts):
        print(f"  {isa}: {counts[isa]}")
    return problems


if __name__ == "__main__":
    issues = main(sys.argv[1] if len(sys.argv) > 1 else "NotOnMyShift.xcodeproj/project.pbxproj")
    if issues:
        print("\nSORUN:")
        for issue in issues:
            print(" -", issue)
        sys.exit(1)
    print("\npbxproj yapısal olarak temiz.")
