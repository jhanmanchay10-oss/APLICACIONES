# -*- coding: utf-8 -*-
"""Empaqueta script.py dentro de un grafo de Dynamo (AndamioTalud.dyn).

Uso:  python3 revit/herramientas/crear_dyn.py [salida.dyn]
"""
import json
import os
import sys
import uuid

AQUI = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(AQUI, "..", "AndamioTalud.extension", "AndamioTalud.tab",
                      "Modelado.panel", "AndamioTalud.pushbutton", "script.py")


def gid():
    return uuid.uuid4().hex


def main(ruta):
    codigo = open(SCRIPT, encoding="utf-8").read()
    nodo = gid()
    grafo = {
        "Uuid": str(uuid.uuid4()),
        "IsCustomNode": False,
        "Description": "Andamio multidireccional sobre talud (001-PA-AND-001)",
        "Name": "AndamioTalud",
        "ElementResolver": {"ResolutionMap": {}},
        "Inputs": [], "Outputs": [],
        "Nodes": [{
            "ConcreteType": "PythonNodeModels.PythonNode, PythonNodeModels",
            "NodeType": "PythonScriptNode",
            "Code": codigo,
            "Engine": "CPython3",
            "VariableInputPorts": True,
            "Id": nodo,
            "Inputs": [{"Id": gid(), "Name": "IN[0]", "Description": "Input #0",
                        "UsingDefaultValue": False, "Level": 2,
                        "UseLevels": False, "KeepListStructure": False}],
            "Outputs": [{"Id": gid(), "Name": "OUT",
                         "Description": "Result of the python script",
                         "UsingDefaultValue": False, "Level": 2,
                         "UseLevels": False, "KeepListStructure": False}],
            "Replication": "Disabled",
            "Description": "Genera el andamio sobre talud en el documento activo",
        }],
        "Connectors": [], "Dependencies": [], "NodeLibraryDependencies": [],
        "Bindings": [],
        "View": {
            "Dynamo": {"ScaleFactor": 1.0, "HasRunWithoutCrash": True,
                       "IsVisibleInDynamoLibrary": True,
                       "Version": "2.13.1.3887", "RunType": "Manual",
                       "RunPeriod": "1000"},
            "Camera": {"Name": "Background Preview", "EyeX": -17.0, "EyeY": 24.0,
                       "EyeZ": 50.0, "LookX": 12.0, "LookY": -13.0,
                       "LookZ": -58.0, "UpX": 0.0, "UpY": 1.0, "UpZ": 0.0},
            "NodeViews": [{"Id": nodo, "Name": "Andamio sobre talud",
                           "IsSetAsInput": False, "IsSetAsOutput": False,
                           "Excluded": False, "ShowGeometry": True,
                           "X": 200.0, "Y": 200.0}],
            "Annotations": [], "X": 0.0, "Y": 0.0, "Zoom": 1.0,
        },
    }
    with open(ruta, "w", encoding="utf-8") as f:
        json.dump(grafo, f, indent=2, ensure_ascii=False)
    print("Grafo Dynamo escrito en %s" % ruta)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "AndamioTalud.dyn")
