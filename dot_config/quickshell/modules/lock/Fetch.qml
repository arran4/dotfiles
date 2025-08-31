pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: root

    anchors.fill: parent
    anchors.margins: Appearance.padding.large * 2
    anchors.topMargin: Appearance.padding.large

    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        spacing: Appearance.spacing.normal

        StyledRect {
            implicitWidth: prompt.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: prompt.implicitHeight + Appearance.padding.normal * 2

            color: Colours.palette.m3primary
            radius: Appearance.rounding.small

            MonoText {
                id: prompt

                anchors.centerIn: parent
                text: ">"
                font.pointSize: root.width > 400 ? Appearance.font.size.larger : Appearance.font.size.normal
                color: Colours.palette.m3onPrimary
            }
        }

        MonoText {
            Layout.fillWidth: true
            text: "caelestiafetch.sh"
            font.pointSize: root.width > 400 ? Appearance.font.size.larger : Appearance.font.size.normal
            elide: Text.ElideRight
        }

        WrappedLoader {
            Layout.fillHeight: true
            active: !iconLoader.active

            sourceComponent: OsLogo {}
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        spacing: height * 0.15

        WrappedLoader {
            id: iconLoader

            Layout.fillHeight: true
            active: root.width > 320

            sourceComponent: OsLogo {}
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.padding.normal
            Layout.bottomMargin: Appearance.padding.normal
            Layout.leftMargin: iconLoader.active ? 0 : width * 0.1
            spacing: Appearance.spacing.normal

            WrappedLoader {
                Layout.fillWidth: true
                active: !batLoader.active && root.height > 200

                sourceComponent: FetchText {
                    text: `OS  : ${SysInfo.osPrettyName || SysInfo.osName}`
                }
            }

            WrappedLoader {
                Layout.fillWidth: true
                active: root.height > (batLoader.active ? 200 : 110)

                sourceComponent: FetchText {
                    text: `WM  : ${SysInfo.wm}`
                }
            }

            WrappedLoader {
                Layout.fillWidth: true
                active: !batLoader.active || root.height > 110

                sourceComponent: FetchText {
                    text: `USER: ${SysInfo.user}`
                }
            }

            FetchText {
                text: `UP  : ${SysInfo.uptime}`
            }

            WrappedLoader {
                id: batLoader

                Layout.fillWidth: true
                active: UPower.displayDevice.isLaptopBattery

                sourceComponent: FetchText {
                    text: `BATT: ${UPower.onBattery ? "" : "(+) "}${Math.round(UPower.displayDevice.percentage * 100)}%`
                }
            }
        }
    }

    WrappedLoader {
        Layout.alignment: Qt.AlignHCenter
        active: root.height > 180

        sourceComponent: RowLayout {
            spacing: Appearance.spacing.large

            Repeater {
                model: Math.max(0, Math.min(8, root.width / (Appearance.font.size.larger * 2 + Appearance.spacing.large)))

                StyledRect {
                    required property int index

                    implicitWidth: implicitHeight
                    implicitHeight: Appearance.font.size.larger * 2
                    color: Colours.palette[`term${index}`]
                    radius: Appearance.rounding.small
                }
            }
        }
    }

    component WrappedLoader: Loader {
        asynchronous: true
        visible: active
    }

    component OsLogo: ColouredIcon {
        source: SysInfo.osLogo
        implicitSize: height
        colour: Colours.palette.m3primary
        layer.enabled: Config.lock.recolourLogo || SysInfo.isDefaultLogo
    }

    component FetchText: MonoText {
        Layout.fillWidth: true
        font.pointSize: root.width > 400 ? Appearance.font.size.larger : Appearance.font.size.normal
        elide: Text.ElideRight
    }

    component MonoText: StyledText {
        font.family: Appearance.font.family.mono
    }
}
