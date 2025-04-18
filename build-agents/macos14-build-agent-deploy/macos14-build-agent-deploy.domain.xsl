<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0">
  <xsl:output omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="node()|@*">
     <xsl:copy>
       <xsl:apply-templates select="node()|@*"/>
     </xsl:copy>
  </xsl:template>

  <xsl:template match="/domain">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates select="node()" />

      <qemu:commandline>
          <qemu:arg value='-device'/>
          <qemu:arg value='isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc'/>
          <qemu:arg value='-smbios'/>
          <qemu:arg value='type=2'/>

          <!-- CPU flags are too specific to set via cpu element in libvirt domain schema, seemingly. -->
          <qemu:arg value='-cpu'/>
          <qemu:arg value='Haswell-noTSX,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check'/>
        </qemu:commandline>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="/domain/os/type">
    <type arch='x86_64' machine='pc-q35-4.2'>hvm</type>
  </xsl:template>

  <xsl:template match="/domain/devices">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates select="node()" />

      <!-- Add USB keyboard and graphics tablet -->
      <input type="keyboard" bus="usb">
        <address type="usb" bus="0" port="2"/>
      </input>
      <input type="tablet" bus="usb">
        <address type="usb" bus="0" port="1"/>
      </input>

      <!-- Add USB 1.0/2.0 controllers instead of the libvirt default of USB 3.0 -->
      <controller type="usb" index="0" model="ich9-ehci1">
        <address type="pci" domain="0x0000" bus="0x00" slot="0x1d" function="0x7"/>
      </controller>
      <controller type="usb" index="0" model="ich9-uhci1">
        <master startport="0"/>
        <address type="pci" domain="0x0000" bus="0x00" slot="0x1d" function="0x0" multifunction="on"/>
      </controller>
      <controller type="usb" index="0" model="ich9-uhci2">
        <master startport="2"/>
        <address type="pci" domain="0x0000" bus="0x00" slot="0x1d" function="0x1"/>
      </controller>
      <controller type="usb" index="0" model="ich9-uhci3">
        <master startport="4"/>
        <address type="pci" domain="0x0000" bus="0x00" slot="0x1d" function="0x2"/>
      </controller>

      <!-- libvirt will not allow changing the PCI address of the "primary" SATA controller, so
           we add a second one at the address used by OSX-KVM to keep the boot parameters valid -->
      <controller type="sata" index="1">
        <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x0"/>
      </controller>
    </xsl:copy>
  </xsl:template>

  <!-- Override default virto disk interfaces with SATA ("SSDs" for TRIM) -->
  <xsl:template match="/domain/devices/disk/target[@dev='vda']">
    <target dev='sda' bus='sata' rotation_rate='1'/>
    <address type="drive" controller="1" bus="0" target="0" unit="2"/>
  </xsl:template>
  <xsl:template match="/domain/devices/disk/target[@dev='vdb']">
    <target dev='sdb' bus='sata' rotation_rate='1'/>
    <address type="drive" controller="1" bus="0" target="0" unit="4"/>
  </xsl:template>

  <!-- Override default IDE CD interface with SATA. -->
  <xsl:template match="/domain/devices/disk[@device='cdrom']/target">
    <target dev='sdc' bus='sata'/>
  </xsl:template>
</xsl:stylesheet>
