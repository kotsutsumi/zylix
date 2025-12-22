#!/usr/bin/env python3
"""
Zylix Test Framework - Linux AT-SPI Bridge Server

HTTP server for Linux desktop automation using AT-SPI2.
Communicates with the Zig Linux driver via HTTP/JSON.

Requirements:
    - Python 3.8+
    - python3-pyatspi (or pyatspi2)
    - python3-gi (GObject Introspection)

Install on Debian/Ubuntu:
    apt install python3-pyatspi at-spi2-core python3-gi

Install on Fedora:
    dnf install python3-pyatspi at-spi2-core python3-gobject
"""

import gi
gi.require_version('Atspi', '2.0')
from gi.repository import Atspi, GLib

import json
import subprocess
import base64
import threading
import socket
import os
import signal
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Dict, Optional, Any, List
from dataclasses import dataclass
from io import BytesIO

# Initialize AT-SPI
Atspi.init()

PORT = 8300
sessions: Dict[str, 'Session'] = {}
session_counter = 0
elements: Dict[str, Atspi.Accessible] = {}
element_counter = 0


@dataclass
class Session:
    """Represents a test session with an application."""
    id: str
    app: Optional[Atspi.Accessible]
    pid: Optional[int]
    window: Optional[Atspi.Accessible]


def store_element(element: Atspi.Accessible) -> str:
    """Store an element and return its ID."""
    global element_counter
    element_counter += 1
    element_id = f"ax-{element_counter}"
    elements[element_id] = element
    return element_id


def get_element(element_id: str) -> Optional[Atspi.Accessible]:
    """Retrieve a stored element."""
    return elements.get(element_id)


def find_app_by_name(name: str) -> Optional[Atspi.Accessible]:
    """Find an application by name."""
    desktop = Atspi.get_desktop(0)
    for i in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(i)
        if app and name.lower() in (app.get_name() or "").lower():
            return app
    return None


def find_app_by_pid(pid: int) -> Optional[Atspi.Accessible]:
    """Find an application by PID."""
    desktop = Atspi.get_desktop(0)
    for i in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(i)
        if app:
            try:
                app_pid = app.get_process_id()
                if app_pid == pid:
                    return app
            except Exception:
                pass
    return None


def find_window(app: Atspi.Accessible, name: Optional[str] = None) -> Optional[Atspi.Accessible]:
    """Find the main window of an application."""
    for i in range(app.get_child_count()):
        child = app.get_child_at_index(i)
        if child:
            role = child.get_role()
            if role in (Atspi.Role.FRAME, Atspi.Role.WINDOW, Atspi.Role.DIALOG):
                if name is None or name.lower() in (child.get_name() or "").lower():
                    return child
    return None


def find_element_by_role(root: Atspi.Accessible, role_name: str) -> Optional[Atspi.Accessible]:
    """Find element by AT-SPI role."""
    role_map = {
        "push button": Atspi.Role.PUSH_BUTTON,
        "button": Atspi.Role.PUSH_BUTTON,
        "text": Atspi.Role.TEXT,
        "entry": Atspi.Role.ENTRY,
        "label": Atspi.Role.LABEL,
        "menu": Atspi.Role.MENU,
        "menu item": Atspi.Role.MENU_ITEM,
        "menu bar": Atspi.Role.MENU_BAR,
        "check box": Atspi.Role.CHECK_BOX,
        "radio button": Atspi.Role.RADIO_BUTTON,
        "combo box": Atspi.Role.COMBO_BOX,
        "list": Atspi.Role.LIST,
        "list item": Atspi.Role.LIST_ITEM,
        "tree": Atspi.Role.TREE,
        "tree item": Atspi.Role.TREE_ITEM,
        "tab": Atspi.Role.PAGE_TAB,
        "tab list": Atspi.Role.PAGE_TAB_LIST,
        "scroll bar": Atspi.Role.SCROLL_BAR,
        "slider": Atspi.Role.SLIDER,
        "progress bar": Atspi.Role.PROGRESS_BAR,
        "frame": Atspi.Role.FRAME,
        "window": Atspi.Role.WINDOW,
        "dialog": Atspi.Role.DIALOG,
        "panel": Atspi.Role.PANEL,
        "toolbar": Atspi.Role.TOOL_BAR,
        "status bar": Atspi.Role.STATUS_BAR,
    }

    target_role = role_map.get(role_name.lower())
    if target_role is None:
        return None

    def search(node: Atspi.Accessible) -> Optional[Atspi.Accessible]:
        if node.get_role() == target_role:
            return node
        for i in range(node.get_child_count()):
            child = node.get_child_at_index(i)
            if child:
                result = search(child)
                if result:
                    return result
        return None

    return search(root)


def find_element_by_name(root: Atspi.Accessible, name: str) -> Optional[Atspi.Accessible]:
    """Find element by accessible name."""
    def search(node: Atspi.Accessible) -> Optional[Atspi.Accessible]:
        node_name = node.get_name() or ""
        if name.lower() in node_name.lower():
            return node
        for i in range(node.get_child_count()):
            child = node.get_child_at_index(i)
            if child:
                result = search(child)
                if result:
                    return result
        return None

    return search(root)


def find_element_by_description(root: Atspi.Accessible, desc: str) -> Optional[Atspi.Accessible]:
    """Find element by accessible description."""
    def search(node: Atspi.Accessible) -> Optional[Atspi.Accessible]:
        node_desc = node.get_description() or ""
        if desc.lower() in node_desc.lower():
            return node
        for i in range(node.get_child_count()):
            child = node.get_child_at_index(i)
            if child:
                result = search(child)
                if result:
                    return result
        return None

    return search(root)


def find_elements_by_role(root: Atspi.Accessible, role_name: str) -> List[Atspi.Accessible]:
    """Find all elements by AT-SPI role."""
    role_map = {
        "push button": Atspi.Role.PUSH_BUTTON,
        "button": Atspi.Role.PUSH_BUTTON,
        "text": Atspi.Role.TEXT,
        "entry": Atspi.Role.ENTRY,
        "label": Atspi.Role.LABEL,
    }

    target_role = role_map.get(role_name.lower())
    if target_role is None:
        return []

    results = []

    def search(node: Atspi.Accessible):
        if node.get_role() == target_role:
            results.append(node)
        for i in range(node.get_child_count()):
            child = node.get_child_at_index(i)
            if child:
                search(child)

    search(root)
    return results


def get_element_text(element: Atspi.Accessible) -> str:
    """Get text from an element."""
    try:
        text_iface = element.get_text()
        if text_iface:
            return text_iface.get_text(0, text_iface.get_character_count())
    except Exception:
        pass

    # Fallback to name
    return element.get_name() or ""


def click_element(element: Atspi.Accessible) -> bool:
    """Click on an element."""
    try:
        action = element.get_action()
        if action:
            for i in range(action.get_n_actions()):
                name = action.get_action_name(i)
                if name in ("click", "activate", "press"):
                    return action.do_action(i)
        # Fallback: use component interface for click
        component = element.get_component()
        if component:
            pos = component.get_position(Atspi.CoordType.SCREEN)
            size = component.get_size()
            x = pos.x + size.x // 2
            y = pos.y + size.y // 2
            Atspi.generate_mouse_event(x, y, "b1c")
            return True
    except Exception as e:
        print(f"Click failed: {e}")
    return False


def type_text(element: Atspi.Accessible, text: str) -> bool:
    """Type text into an element."""
    try:
        # Focus the element first
        component = element.get_component()
        if component:
            component.grab_focus()

        # Use editable text interface
        editable = element.get_editable_text()
        if editable:
            # Clear existing text
            text_iface = element.get_text()
            if text_iface:
                length = text_iface.get_character_count()
                if length > 0:
                    editable.delete_text(0, length)
            # Insert new text
            return editable.insert_text(0, text, len(text))

        # Fallback: simulate keyboard
        for char in text:
            Atspi.generate_keyboard_event(0, char, Atspi.KeySynthType.STRING)
        return True
    except Exception as e:
        print(f"Type text failed: {e}")
    return False


def take_screenshot(window: Atspi.Accessible) -> Optional[str]:
    """Take a screenshot of the window."""
    try:
        component = window.get_component()
        if component:
            pos = component.get_position(Atspi.CoordType.SCREEN)
            size = component.get_size()

            # Use gnome-screenshot or scrot
            import tempfile
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
                filename = f.name

            # Try gnome-screenshot first
            try:
                subprocess.run([
                    "gnome-screenshot", "-a",
                    f"--area={pos.x},{pos.y},{size.x},{size.y}",
                    "-f", filename
                ], check=True, capture_output=True)
            except Exception:
                # Fallback to scrot
                subprocess.run([
                    "scrot", "-a", f"{pos.x},{pos.y},{size.x},{size.y}", filename
                ], check=True, capture_output=True)

            with open(filename, "rb") as f:
                data = f.read()
            os.unlink(filename)
            return base64.b64encode(data).decode()
    except Exception as e:
        print(f"Screenshot failed: {e}")
    return None


class RequestHandler(BaseHTTPRequestHandler):
    """HTTP request handler for AT-SPI commands."""

    def log_message(self, format, *args):
        # Suppress default logging
        pass

    def do_POST(self):
        """Handle POST requests."""
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8')

        try:
            data = json.loads(body) if body else {}
        except json.JSONDecodeError:
            data = {}

        result = handle_command(self.path, data)

        response = json.dumps(result).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(response))
        self.end_headers()
        self.wfile.write(response)


def handle_command(path: str, data: Dict[str, Any]) -> Dict[str, Any]:
    """Handle a command from the Zig driver."""
    global session_counter

    parts = [p for p in path.split('/') if p]

    if len(parts) < 2 or parts[0] != "session":
        return {"error": "Invalid path"}

    # New session
    if parts[1] == "new" and len(parts) >= 3:
        if parts[2] == "launch":
            return handle_launch(data)
        elif parts[2] == "attach":
            return handle_attach(data)

    # Existing session
    session_id = parts[1]
    session = sessions.get(session_id)
    if not session:
        return {"error": "Session not found"}

    if len(parts) < 3:
        return {"error": "Missing command"}

    command = parts[2]
    handlers = {
        "close": lambda: handle_close(session),
        "findElement": lambda: handle_find_element(session, data),
        "findElements": lambda: handle_find_elements(session, data),
        "click": lambda: handle_click(session, data),
        "doubleClick": lambda: handle_double_click(session, data),
        "rightClick": lambda: handle_right_click(session, data),
        "type": lambda: handle_type(session, data),
        "clear": lambda: handle_clear(session, data),
        "getText": lambda: handle_get_text(session, data),
        "getName": lambda: handle_get_name(session, data),
        "getRole": lambda: handle_get_role(session, data),
        "getDescription": lambda: handle_get_description(session, data),
        "isVisible": lambda: handle_is_visible(session, data),
        "isEnabled": lambda: handle_is_enabled(session, data),
        "isFocused": lambda: handle_is_focused(session, data),
        "focus": lambda: handle_focus(session, data),
        "getBounds": lambda: handle_get_bounds(session, data),
        "getAttribute": lambda: handle_get_attribute(session, data),
        "screenshot": lambda: handle_screenshot(session),
        "elementScreenshot": lambda: handle_element_screenshot(session, data),
        "window": lambda: handle_window_info(session),
        "keys": lambda: handle_keys(session, data),
    }

    handler = handlers.get(command)
    if handler:
        return handler()

    return {"error": f"Unknown command: {command}"}


def handle_launch(data: Dict[str, Any]) -> Dict[str, Any]:
    """Launch an application."""
    global session_counter

    desktop_file = data.get("desktopFile")
    executable = data.get("executable")
    args = data.get("args", [])
    working_dir = data.get("workingDir")

    pid = None

    try:
        if desktop_file:
            # Launch via desktop file
            cmd = ["gtk-launch", desktop_file]
            proc = subprocess.Popen(cmd, cwd=working_dir)
            pid = proc.pid
        elif executable:
            # Launch executable directly
            cmd = [executable] + args
            proc = subprocess.Popen(cmd, cwd=working_dir)
            pid = proc.pid
        else:
            return {"error": "Missing desktopFile or executable"}

        # Wait for app to appear in AT-SPI tree
        import time
        app = None
        for _ in range(50):  # 5 second timeout
            time.sleep(0.1)
            app = find_app_by_pid(pid)
            if app:
                break

        if not app:
            return {"error": "App not found in AT-SPI tree"}

        session_counter += 1
        session_id = f"session-{session_counter}"

        window = find_window(app)

        sessions[session_id] = Session(
            id=session_id,
            app=app,
            pid=pid,
            window=window
        )

        return {
            "sessionId": session_id,
            "pid": pid,
            "success": True
        }
    except Exception as e:
        return {"error": str(e)}


def handle_attach(data: Dict[str, Any]) -> Dict[str, Any]:
    """Attach to a running application."""
    global session_counter

    pid = data.get("pid")
    window_name = data.get("windowName")
    app_name = data.get("appName")

    app = None

    if pid:
        app = find_app_by_pid(pid)
    elif app_name:
        app = find_app_by_name(app_name)
    elif window_name:
        # Search all apps for window
        desktop = Atspi.get_desktop(0)
        for i in range(desktop.get_child_count()):
            app_candidate = desktop.get_child_at_index(i)
            if app_candidate:
                window = find_window(app_candidate, window_name)
                if window:
                    app = app_candidate
                    break

    if not app:
        return {"error": "App not found"}

    session_counter += 1
    session_id = f"session-{session_counter}"

    window = find_window(app, window_name)

    try:
        app_pid = app.get_process_id()
    except Exception:
        app_pid = None

    sessions[session_id] = Session(
        id=session_id,
        app=app,
        pid=app_pid,
        window=window
    )

    return {
        "sessionId": session_id,
        "pid": app_pid,
        "success": True
    }


def handle_close(session: Session) -> Dict[str, Any]:
    """Close the session."""
    if session.pid:
        try:
            os.kill(session.pid, signal.SIGTERM)
        except Exception:
            pass

    del sessions[session.id]
    return {"success": True}


def handle_find_element(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Find an element."""
    strategy = data.get("strategy")
    value = data.get("value")
    parent_id = data.get("parentId")

    root = session.window or session.app
    if parent_id:
        root = get_element(parent_id) or root

    if not root:
        return {"error": "No root element"}

    element = None

    if strategy == "role":
        element = find_element_by_role(root, value)
    elif strategy == "name":
        element = find_element_by_name(root, value)
    elif strategy == "description":
        element = find_element_by_description(root, value)
    elif strategy == "application":
        element = find_app_by_name(value)

    if element:
        element_id = store_element(element)
        return {"elementId": element_id}

    return {"elementId": None}


def handle_find_elements(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Find multiple elements."""
    strategy = data.get("strategy")
    value = data.get("value")

    root = session.window or session.app
    if not root:
        return {"elements": []}

    found = []

    if strategy == "role":
        found = find_elements_by_role(root, value)

    element_ids = [store_element(el) for el in found]
    return {"elements": element_ids}


def handle_click(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Click an element."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    if click_element(element):
        return {"success": True}
    return {"error": "Click failed"}


def handle_double_click(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Double-click an element."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    try:
        component = element.get_component()
        if component:
            pos = component.get_position(Atspi.CoordType.SCREEN)
            size = component.get_size()
            x = pos.x + size.x // 2
            y = pos.y + size.y // 2
            Atspi.generate_mouse_event(x, y, "b1d")
            return {"success": True}
    except Exception as e:
        return {"error": str(e)}

    return {"error": "Double click failed"}


def handle_right_click(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Right-click an element."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    try:
        component = element.get_component()
        if component:
            pos = component.get_position(Atspi.CoordType.SCREEN)
            size = component.get_size()
            x = pos.x + size.x // 2
            y = pos.y + size.y // 2
            Atspi.generate_mouse_event(x, y, "b3c")
            return {"success": True}
    except Exception as e:
        return {"error": str(e)}

    return {"error": "Right click failed"}


def handle_type(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Type text into an element."""
    element = get_element(data.get("elementId", ""))
    text = data.get("text", "")

    if not element:
        return {"error": "Element not found"}

    if type_text(element, text):
        return {"success": True}
    return {"error": "Type failed"}


def handle_clear(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Clear element text."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    try:
        editable = element.get_editable_text()
        if editable:
            text_iface = element.get_text()
            if text_iface:
                length = text_iface.get_character_count()
                if length > 0:
                    editable.delete_text(0, length)
                    return {"success": True}
        return {"success": True}
    except Exception as e:
        return {"error": str(e)}


def handle_get_text(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Get element text."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    text = get_element_text(element)
    return {"value": text}


def handle_get_name(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Get element name."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    return {"value": element.get_name() or ""}


def handle_get_role(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Get element role."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    role = element.get_role()
    return {"value": role.value_nick if hasattr(role, 'value_nick') else str(role)}


def handle_get_description(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Get element description."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    return {"value": element.get_description() or ""}


def handle_is_visible(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Check if element is visible."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"value": False}

    try:
        state_set = element.get_state_set()
        return {"value": state_set.contains(Atspi.StateType.VISIBLE)}
    except Exception:
        return {"value": False}


def handle_is_enabled(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Check if element is enabled."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"value": False}

    try:
        state_set = element.get_state_set()
        return {"value": state_set.contains(Atspi.StateType.ENABLED)}
    except Exception:
        return {"value": False}


def handle_is_focused(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Check if element is focused."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"value": False}

    try:
        state_set = element.get_state_set()
        return {"value": state_set.contains(Atspi.StateType.FOCUSED)}
    except Exception:
        return {"value": False}


def handle_focus(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Focus an element."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    try:
        component = element.get_component()
        if component:
            component.grab_focus()
            return {"success": True}
    except Exception as e:
        return {"error": str(e)}

    return {"error": "Focus failed"}


def handle_get_bounds(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Get element bounds."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    try:
        component = element.get_component()
        if component:
            pos = component.get_position(Atspi.CoordType.SCREEN)
            size = component.get_size()
            return {
                "x": pos.x,
                "y": pos.y,
                "width": size.x,
                "height": size.y
            }
    except Exception as e:
        return {"error": str(e)}

    return {"x": 0, "y": 0, "width": 0, "height": 0}


def handle_get_attribute(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Get element attribute."""
    element = get_element(data.get("elementId", ""))
    name = data.get("name", "")

    if not element:
        return {"error": "Element not found"}

    try:
        attrs = element.get_attributes()
        return {"value": attrs.get(name, "")}
    except Exception:
        return {"value": ""}


def handle_screenshot(session: Session) -> Dict[str, Any]:
    """Take application screenshot."""
    window = session.window or session.app
    if not window:
        return {"error": "No window"}

    data = take_screenshot(window)
    if data:
        return {"data": data}
    return {"error": "Screenshot failed"}


def handle_element_screenshot(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Take element screenshot."""
    element = get_element(data.get("elementId", ""))
    if not element:
        return {"error": "Element not found"}

    screenshot_data = take_screenshot(element)
    if screenshot_data:
        return {"data": screenshot_data}
    return {"error": "Screenshot failed"}


def handle_window_info(session: Session) -> Dict[str, Any]:
    """Get window information."""
    window = session.window or session.app
    if not window:
        return {"error": "No window"}

    result = {
        "title": window.get_name() or ""
    }

    try:
        component = window.get_component()
        if component:
            pos = component.get_position(Atspi.CoordType.SCREEN)
            size = component.get_size()
            result.update({
                "x": pos.x,
                "y": pos.y,
                "width": size.x,
                "height": size.y
            })
    except Exception:
        pass

    return result


def handle_keys(session: Session, data: Dict[str, Any]) -> Dict[str, Any]:
    """Send keyboard input."""
    keys = data.get("keys", "")

    try:
        for char in keys:
            Atspi.generate_keyboard_event(0, char, Atspi.KeySynthType.STRING)
        return {"success": True}
    except Exception as e:
        return {"error": str(e)}


def main():
    """Start the HTTP server."""
    print(f"ZylixTest Linux AT-SPI Server starting on port {PORT}")

    server = HTTPServer(('127.0.0.1', PORT), RequestHandler)
    print(f"Server running on http://127.0.0.1:{PORT}")
    print("Press Ctrl+C to stop")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
