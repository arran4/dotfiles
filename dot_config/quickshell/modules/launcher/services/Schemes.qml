pragma Singleton

import ".."
import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
  id: root

  function transformSearch(search: string): string {
  return search.slice(`${Config.launcher.actionPrefix}scheme `.length);
  }

  function selector(item: var): string {
  return `${item.name} ${item.flavour}`;
  }

  list: schemes.instances
  useFuzzy: Config.launcher.useFuzzy.schemes
  keys: ["name", "flavour"]
  weights: [0.9, 0.1]

  Variants {
  id: schemes

  Scheme {}
  }

  Process {
  id: getSchemes

  running: true
  command: ["caelestia", "scheme", "list"]
  stdout: StdioCollector {
    onStreamFinished: {
    const schemeData = JSON.parse(text);
    const list = Object.entries(schemeData).map(([name, f]) => Object.entries(f).map(([flavour, colours]) => ({
        name,
        flavour,
        colours
        })));

    const flat = [];
    for (const s of list)
      for (const f of s)
      flat.push(f);

    schemes.model = flat;
    }
  }
  }

  component Scheme: QtObject {
  required property var modelData
  readonly property string name: modelData.name
  readonly property string flavour: modelData.flavour
  readonly property var colours: modelData.colours

  function onClicked(list: AppList): void {
    list.visibilities.launcher = false;
    Quickshell.execDetached(["caelestia", "scheme", "set", "-n", name, "-f", flavour]);
  }
  }
}
