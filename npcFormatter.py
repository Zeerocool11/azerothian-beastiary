import re
import csv
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from datetime import datetime
from pathlib import Path

APP_NAME = "Azerothian Beastiary Formatter"

def find_matching_brace(text, start):
    """
    Given the position of an opening {, return the position
    of its matching }.
    """

    depth = 0
    in_string = False
    escape = False

    for i in range(start, len(text)):
        char = text[i]

        if in_string:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                in_string = False

            continue

        if char == '"':
            in_string = True

        elif char == "{":
            depth += 1

        elif char == "}":
            depth -= 1

            if depth == 0:
                return i

    raise ValueError("Could not find matching Lua table brace.")

def get_string(text, key):
    pattern = rf'\["{re.escape(key)}"\]\s*=\s*"([^"]*)"'
    match = re.search(pattern, text)

    if match:
        return match.group(1)

    return None


def get_number(text, key):
    pattern = rf'\["{re.escape(key)}"\]\s*=\s*(-?\d+)'
    match = re.search(pattern, text)

    if match:
        return int(match.group(1))

    return None


def get_boolean(text, key):
    pattern = rf'\["{re.escape(key)}"\]\s*=\s*(true|false)'
    match = re.search(pattern, text)

    if not match:
        return None

    return match.group(1) == "true"


# ============================================================
# EXTRACT LUA TABLE
# ============================================================

def extract_named_table(text, key):
    """
    Finds:

    ["key"] = {

    and returns only the contents of that Lua table.
    """

    pattern = rf'\["{re.escape(key)}"\]\s*=\s*\{{'

    match = re.search(pattern, text)

    if not match:
        return None

    opening_brace = text.find("{", match.start())

    closing_brace = find_matching_brace(
        text,
        opening_brace
    )

    return text[
        opening_brace + 1:
        closing_brace
    ]


# ============================================================
# LOCATION PARSER
# ============================================================

def parse_locations(npc_text):

    location_table = extract_named_table(
        npc_text,
        "locations"
    )

    if location_table is None:
        return []

    locations = []

    location_pattern = re.compile(
        r'\["([^"]+)"\]\s*=\s*\{'
    )

    position = 0

    while True:

        match = location_pattern.search(
            location_table,
            position
        )

        if not match:
            break

        location_key = match.group(1)

        opening_brace = location_table.find(
            "{",
            match.start()
        )

        closing_brace = find_matching_brace(
            location_table,
            opening_brace
        )

        body = location_table[
            opening_brace + 1:
            closing_brace
        ]

        locations.append({
            "key": location_key,
            "mapID": get_number(body, "mapID"),
            "mapName": get_string(body, "mapName"),
            "inInstance": get_boolean(
                body,
                "inInstance"
            ),
            "instanceType": get_string(
                body,
                "instanceType"
            ),
            "instanceName": get_string(
                body,
                "instanceName"
            ),
            "firstSeen": get_number(
                body,
                "firstSeen"
            ),
        })

        position = closing_brace + 1

    return locations


# ============================================================
# NPC PARSER
# ============================================================

def parse_npcs(text):

    npc_table = extract_named_table(
        text,
        "npcs"
    )

    if npc_table is None:
        raise ValueError(
            'Could not find ["npcs"] table.'
        )

    npc_pattern = re.compile(
        r'\[(\d+)\]\s*=\s*\{'
    )

    npcs = []

    position = 0

    while True:

        match = npc_pattern.search(
            npc_table,
            position
        )

        if not match:
            break

        npc_id = int(
            match.group(1)
        )

        opening_brace = npc_table.find(
            "{",
            match.start()
        )

        closing_brace = find_matching_brace(
            npc_table,
            opening_brace
        )

        body = npc_table[
            opening_brace + 1:
            closing_brace
        ]

        npc = {
            "id": npc_id,

            "name":
                get_string(
                    body,
                    "name"
                )
                or "Unknown",

            "seenCount":
                get_number(
                    body,
                    "seenCount"
                )
                or 0,

            "firstSeen":
                get_number(
                    body,
                    "firstSeen"
                ),

            "lastSeen":
                get_number(
                    body,
                    "lastSeen"
                ),

            "firstSource":
                get_string(
                    body,
                    "firstSource"
                ),

            "lastSource":
                get_string(
                    body,
                    "lastSource"
                ),

            "locations":
                parse_locations(
                    body
                )
        }

        npcs.append(npc)

        position = closing_brace + 1

    return npcs


# ============================================================
# SAVED VARIABLES PARSER
# ============================================================

def parse_saved_variables(text):

    if "AzerothianBeastiaryDB" not in text:

        raise ValueError(
            "This does not appear to be an "
            "Azerothian Beastiary SavedVariables file."
        )

    version = get_string(
        text,
        "version"
    )

    npcs = parse_npcs(
        text
    )

    return {
        "version": version,
        "npcs": npcs
    }


# ============================================================
# FORMATTING
# ============================================================

def format_timestamp(timestamp):

    if timestamp is None:
        return "Unknown"

    try:

        return datetime.fromtimestamp(
            timestamp
        ).strftime(
            "%Y-%m-%d %H:%M:%S"
        )

    except (
        ValueError,
        OverflowError,
        OSError
    ):
        return str(timestamp)


def get_location_name(location):

    if location["inInstance"]:

        return (
            location["instanceName"]
            or location["mapName"]
            or "Unknown Instance"
        )

    return (
        location["mapName"]
        or "Unknown Zone"
    )


# ============================================================
# CLEAN NPC LIST
# ============================================================

def build_clean_rows(npcs):

    rows = []

    for npc in npcs:

        location_names = []

        for location in npc["locations"]:

            name = get_location_name(
                location
            )

            if name not in location_names:
                location_names.append(name)

        rows.append({

            "id":
                npc["id"],

            "name":
                npc["name"],

            "seenCount":
                npc["seenCount"],

            "locations":
                location_names,

            "firstSeen":
                format_timestamp(
                    npc["firstSeen"]
                ),

            "lastSeen":
                format_timestamp(
                    npc["lastSeen"]
                ),

            "firstSource":
                npc["firstSource"]
                or "Unknown",

            "lastSource":
                npc["lastSource"]
                or "Unknown"

        })

    return rows


# ============================================================
# TEXT EXPORT
# ============================================================

def create_text_output(rows):

    total_encounters = sum(
        npc["seenCount"]
        for npc in rows
    )

    zones = {}

    for npc in rows:

        npc_zones = (
            npc["locations"]
            or ["Unknown Zone"]
        )

        for zone in npc_zones:

            zones.setdefault(
                zone,
                []
            )

            zones[zone].append(
                npc
            )

    output = []

    output.append(
        "AZEROTHIAN BESTIARY"
    )

    output.append(
        "=" * 70
    )

    output.append(
        f"Unique NPC IDs: {len(rows)}"
    )

    output.append(
        f"Total Encounters: {total_encounters}"
    )

    output.append(
        f"Locations: {len(zones)}"
    )

    output.append("")

    for zone in sorted(
        zones.keys(),
        key=str.lower
    ):

        output.append(
            zone.upper()
        )

        output.append(
            "-" * len(zone)
        )

        npcs = sorted(
            zones[zone],
            key=lambda x:
                (
                    x["name"].lower(),
                    x["id"]
                )
        )

        for npc in npcs:

            output.append(
                f'{npc["id"]:>8}  '
                f'{npc["name"]}'
            )

        output.append("")

    return "\n".join(
        output
    )


# ============================================================
# CSV EXPORT
# ============================================================

def save_csv(rows, filename):

    with open(
        filename,
        "w",
        newline="",
        encoding="utf-8-sig"
    ) as file:

        writer = csv.writer(
            file
        )

        writer.writerow([
            "NPC ID",
            "Name",
            "Locations",
            "Encounters",
            "First Seen",
            "Last Seen",
            "First Source",
            "Last Source"
        ])

        for npc in sorted(
            rows,
            key=lambda x:
                (
                    x["name"].lower(),
                    x["id"]
                )
        ):

            writer.writerow([

                npc["id"],

                npc["name"],

                "; ".join(
                    npc["locations"]
                ),

                npc["seenCount"],

                npc["firstSeen"],

                npc["lastSeen"],

                npc["firstSource"],

                npc["lastSource"]

            ])


# ============================================================
# GUI
# ============================================================

class BestiaryFormatter(tk.Tk):

    def __init__(self):

        super().__init__()

        self.title(
            APP_NAME
        )

        self.geometry(
            "1050x720"
        )

        self.minsize(
            850,
            600
        )

        self.data = None
        self.rows = []

        self.file_path = tk.StringVar(
            value="No SavedVariables file selected."
        )

        self.npc_stat = tk.StringVar(
            value="NPCs\n—"
        )

        self.encounter_stat = tk.StringVar(
            value="Encounters\n—"
        )

        self.zone_stat = tk.StringVar(
            value="Locations\n—"
        )

        self.duplicate_stat = tk.StringVar(
            value="Shared Names\n—"
        )

        self.build_interface()


    # ========================================================
    # UI
    # ========================================================

    def build_interface(self):

        self.columnconfigure(
            0,
            weight=1
        )

        self.rowconfigure(
            4,
            weight=1
        )

        title = ttk.Label(
            self,
            text="AZEROTHIAN BESTIARY FORMATTER",
            font=(
                "Segoe UI",
                22,
                "bold"
            )
        )

        title.grid(
            row=0,
            column=0,
            sticky="w",
            padx=20,
            pady=(20, 5)
        )


        description = ttk.Label(
            self,
            text=(
                "Convert AzerothianBeastiary "
                "SavedVariables into a clean NPC list."
            )
        )

        description.grid(
            row=1,
            column=0,
            sticky="w",
            padx=20
        )


        # ----------------------------------------------------
        # File selector
        # ----------------------------------------------------

        file_frame = ttk.LabelFrame(
            self,
            text="SavedVariables File"
        )

        file_frame.grid(
            row=2,
            column=0,
            sticky="ew",
            padx=20,
            pady=15
        )

        file_frame.columnconfigure(
            0,
            weight=1
        )


        ttk.Label(
            file_frame,
            textvariable=self.file_path
        ).grid(
            row=0,
            column=0,
            sticky="ew",
            padx=10,
            pady=10
        )


        ttk.Button(
            file_frame,
            text="Browse",
            command=self.select_file
        ).grid(
            row=0,
            column=1,
            padx=5
        )


        ttk.Button(
            file_frame,
            text="Load",
            command=self.load_file
        ).grid(
            row=0,
            column=2,
            padx=10
        )


        # ----------------------------------------------------
        # Stats
        # ----------------------------------------------------

        stats = ttk.Frame(
            self
        )

        stats.grid(
            row=3,
            column=0,
            sticky="ew",
            padx=20
        )


        stats.columnconfigure(
            (0, 1, 2, 3),
            weight=1
        )


        variables = [

            self.npc_stat,

            self.encounter_stat,

            self.zone_stat,

            self.duplicate_stat

        ]


        for column, variable in enumerate(
            variables
        ):

            label = ttk.Label(
                stats,
                textvariable=variable,
                anchor="center",
                relief="groove",
                padding=12,
                font=(
                    "Segoe UI",
                    10,
                    "bold"
                )
            )

            label.grid(
                row=0,
                column=column,
                sticky="ew",
                padx=4
            )


        # ----------------------------------------------------
        # Preview
        # ----------------------------------------------------

        preview_frame = ttk.LabelFrame(
            self,
            text="Formatted Preview"
        )

        preview_frame.grid(
            row=4,
            column=0,
            sticky="nsew",
            padx=20,
            pady=15
        )

        preview_frame.columnconfigure(
            0,
            weight=1
        )

        preview_frame.rowconfigure(
            0,
            weight=1
        )


        self.preview = tk.Text(
            preview_frame,
            wrap="none",
            font=(
                "Consolas",
                10
            )
        )

        self.preview.grid(
            row=0,
            column=0,
            sticky="nsew"
        )


        scrollbar = ttk.Scrollbar(
            preview_frame,
            command=self.preview.yview
        )

        scrollbar.grid(
            row=0,
            column=1,
            sticky="ns"
        )

        self.preview.configure(
            yscrollcommand=
                scrollbar.set
        )


        # ----------------------------------------------------
        # Buttons
        # ----------------------------------------------------

        button_frame = ttk.Frame(
            self
        )

        button_frame.grid(
            row=5,
            column=0,
            sticky="ew",
            padx=20,
            pady=(0, 20)
        )


        ttk.Button(
            button_frame,
            text="Export TXT",
            command=self.export_txt
        ).pack(
            side="left",
            padx=5
        )


        ttk.Button(
            button_frame,
            text="Export CSV",
            command=self.export_csv
        ).pack(
            side="left",
            padx=5
        )


        ttk.Button(
            button_frame,
            text="Copy Preview",
            command=self.copy_preview
        ).pack(
            side="left",
            padx=5
        )


    # ========================================================
    # FILE OPERATIONS
    # ========================================================

    def select_file(self):

        filename = filedialog.askopenfilename(

            title=
                "Select AzerothianBeastiary SavedVariables",

            filetypes=[
                (
                    "Lua Files",
                    "*.lua"
                ),
                (
                    "All Files",
                    "*.*"
                )
            ]
        )

        if filename:

            self.file_path.set(
                filename
            )


    def load_file(self):

        filename = self.file_path.get()

        if (
            not filename
            or filename.startswith(
                "No SavedVariables"
            )
        ):

            messagebox.showwarning(
                APP_NAME,
                "Select a SavedVariables file first."
            )

            return


        try:

            text = Path(
                filename
            ).read_text(
                encoding="utf-8"
            )

            self.data = (
                parse_saved_variables(
                    text
                )
            )

            self.rows = (
                build_clean_rows(
                    self.data["npcs"]
                )
            )

            self.update_statistics()

            formatted = (
                create_text_output(
                    self.rows
                )
            )

            self.preview.delete(
                "1.0",
                tk.END
            )

            self.preview.insert(
                "1.0",
                formatted
            )


        except Exception as error:

            messagebox.showerror(
                APP_NAME,
                f"Unable to parse file:\n\n{error}"
            )


    # ========================================================
    # STATISTICS
    # ========================================================

    def update_statistics(self):

        total_encounters = sum(
            npc["seenCount"]
            for npc in self.rows
        )

        zones = set()

        for npc in self.rows:

            for zone in npc[
                "locations"
            ]:

                zones.add(
                    zone
                )


        # Find NPC names attached to >1 ID

        names = {}

        for npc in self.rows:

            names.setdefault(
                npc["name"],
                []
            )

            names[
                npc["name"]
            ].append(
                npc["id"]
            )


        shared_names = sum(

            1

            for ids in names.values()

            if len(ids) > 1
        )


        self.npc_stat.set(
            f"NPC IDs\n{len(self.rows):,}"
        )

        self.encounter_stat.set(
            f"Encounters\n{total_encounters:,}"
        )

        self.zone_stat.set(
            f"Locations\n{len(zones):,}"
        )

        self.duplicate_stat.set(
            f"Shared Names\n{shared_names:,}"
        )


    # ========================================================
    # EXPORT
    # ========================================================

    def export_txt(self):

        if not self.rows:
            return


        filename = (
            filedialog.asksaveasfilename(

                defaultextension=".txt",

                filetypes=[
                    (
                        "Text Files",
                        "*.txt"
                    )
                ]
            )
        )


        if filename:

            Path(
                filename
            ).write_text(

                create_text_output(
                    self.rows
                ),

                encoding="utf-8"
            )


    def export_csv(self):

        if not self.rows:
            return


        filename = (
            filedialog.asksaveasfilename(

                defaultextension=".csv",

                filetypes=[
                    (
                        "CSV Files",
                        "*.csv"
                    )
                ]
            )
        )


        if filename:

            save_csv(
                self.rows,
                filename
            )


    def copy_preview(self):

        text = self.preview.get(
            "1.0",
            tk.END
        )

        self.clipboard_clear()

        self.clipboard_append(
            text
        )


# ============================================================
# START APPLICATION
# ============================================================

if __name__ == "__main__":

    app = BestiaryFormatter()

    app.mainloop()
