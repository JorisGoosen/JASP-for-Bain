//
// Copyright (C) 2013-2018 University of Amsterdam
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see
// <http://www.gnu.org/licenses/>.
//
import QtQuick 2.8
import QtQuick.Layouts 1.3
import JASP.Controls 1.0

Form {
    id: form

    VariablesForm {
        AvailableVariablesList { name: "variablesList"}
        AssignedVariablesList {
            name: "dependent"
            title: qsTr("Dependent Variable")
            singleVariable: true
            allowedColumns: ["scale"]
        }

        AssignedVariablesList {
            name: "fixedFactors"
            title: qsTr("Fixed Factors")
            singleVariable: true
            allowedColumns: ["ordinal", "nominal"]
        }

    }

    GridLayout {
      columns: 2

        GroupBox {
            title: qsTr("Tables")

              CheckBox {
                  name: "BFmatrix"
                  text: qsTr("Bayes factor matrix")
              }

              CheckBox {
                  id: descriptives
                  name: "descriptives"
                  text: qsTr("Descriptives")
              }
              PercentField {
                name: "CredibleInterval"
                Layout.leftMargin: 25
                text: qsTr("Credible interval")
                decimals: 1
                defaultValue: 95
                enabled: descriptives.checked
              }
            }

            GroupBox {
                title: qsTr("Plots")

                  CheckBox {
                      name: "BFplot"
                      text: qsTr("Bayes factor comparison")
                  }

                  CheckBox {
                      name: "plotDescriptives"
                      text: qsTr("Descriptives plot")
                  }
                }
        }

    Text {
      text: "Place each hypothesis on a new line. For example:\n\nfactor.low = factor.med = factor.high\nfactor.low < factor.med < factor.high\n\nwhere factor is the factor name and low/med/high are the factor level names."
    }

    ExpanderButton {
        text: qsTr("Model Constraints")

        TextArea {
            name: "model"
            implicitHeight: 200
            infoText: Qt.platform.os == "osx" ? "\u2318 + Enter to apply" : "Crtl + Enter to apply"
            text: ""
        }
    }
}
