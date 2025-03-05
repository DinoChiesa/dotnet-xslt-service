# XSLT Processing using .NET in Google Cloud Run

This is an example of a Cloud Run service. This service implemented in C#, and
runs on .NET 8.0, and exposes a minimal Web API - effectively it is a
microservice. The primary function of this service is to perform XSL Transforms
via [XSLT](https://en.wikipedia.org/wiki/XSLT).

## Disclaimer

This example is not an official Google product, nor is it part of an
official Google product.

## Purpose

Performing XSLT within C# is not rocket science.  Why does this example exist? 

I began exploring this after connecting with several different companies who
observed that they were performing XSLT using a different engine, which was
reaching end-of-life . And they wanted to explore alternatives.  Some of these
companies were using some vendor-specific extensions to XSLT - notably
[msxsl:script](https://learn.microsoft.com/en-us/dotnet/standard/data/xml/script-blocks-using-msxsl-script),
which allows you to embed C# code directly into an XSLT, and invoke it from
within any of the templates.  On .NET, that feature is not supported; it
requires the .NET Framework.

This example illustrates the use of something called an ["Extension
object"](https://learn.microsoft.com/en-us/dotnet/api/system.xml.xsl.xsltargumentlist.addextensionobject?view=net-8.0)
which allows similar capability but without the aspect of co-mingling C# code
and XSLT in one file, as you can do when using `msxsl:script`. To use an
Extension object, you encapsulate your C# code in a separately-compiled
assembly, and then reference the object when the XslTransform is instantiated.

So, the reason this example exists is to illustrate this combination:
- a .NET minimal Web API
- running as a Cloud Run service in Google Cloud
- performing XSLT
- which itself references a separate C# class

## In a Little More Detail

In the [documentation for script blocks](https://learn.microsoft.com/en-us/dotnet/standard/data/xml/script-blocks-using-msxsl-script#calcxsl),
Microsoft offers this example of using `msxsl:script`:

```xml
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:msxsl="urn:schemas-microsoft-com:xslt"
  xmlns:user="urn:my-scripts">
  <msxsl:script language="C#" implements-prefix="user">
  <![CDATA[
  public double circumference(double radius){
    double pi = 3.14;
    double circ = pi*radius*2;
    return circ;
  }
  ]]>
  </msxsl:script>
  <xsl:template match="data">
    <circles>
      <xsl:for-each select="circle">
        <circle>
          <xsl:copy-of select="node()"/>
          <circumference>
            <xsl:value-of select="user:circumference(radius)"/>
          </circumference>
        </circle>
      </xsl:for-each>
    </circles>
  </xsl:template>
</xsl:stylesheet>
```

And by applying that transform to the appropriate XML input file, the transform
can invoke the C# code to perform the calculation. Of course the C# code can do
... anything. It's not limited to arithmetic. Once the code gets beyond a few
lines, though, it seems inelegant to co-mingle the C# with the XSL. For
quick/dirty solution, script blocks will work great. For use within a larger
company or enterprise, you really want to manage distinct bits of code in
separate files, possibly or probably in separate source code repos.

The Extension Block approach allows that.  With Extension blocks, you can  do
something similar. The XSLT is like so:


```xml
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:ext="urn:my-extension-object">
  <xsl:template match="data">
    <circles>
      <xsl:for-each select="circle">
        <circle>
          <xsl:copy-of select="node()"/>
          <circumference>
            <xsl:value-of select="ext:Circumference(radius)"/>
          </circumference>
        </circle>
      </xsl:for-each>
    </circles>
  </xsl:template>
</xsl:stylesheet>
```

But in this case, the C# code is managed in an independent module:

```
namespace XsltEngineDemo;

public class ExtObject
{
    public double Circumference(double radius)
    {
        // perform a local calculation.
        double pi = 3.14159;
        double circ = pi * radius * 2;
        return circ;
    }
}
```

And to use that code, you need to refer to an instance of that object when you execute the transform:

```
      XslCompiledTransform xslt = new XslCompiledTransform();
      xslt.Load(xsltFilename, null /* xsltSettings */, new XmlUrlResolver());

      XsltArgumentList xslArglist = new XsltArgumentList();
      ExtObject obj = new ExtObject();
      // register that object at a particular namespace
      xslArglist.AddExtensionObject("urn:my-extension-object", obj);
      ...
          // Execute the transformation
          xslt.Transform(doc, xslArglist, xmlWriter);
```      

This repo shows a variety of options for demonstrating this capability.

## Demonstrations included here

There are three distinct demonstrations included here, of XSLT that call out to
an extension object defined in C#:

- [circle](./circle) - an object that performs a calculation of a
  Circle's circumference, and returns a simple result - a double - that can
  be embedded directly into the XSL output.
  
- [claims-simple](./claims-simple) - an extension object that checks through a
  medical claim and performs some analysis of it. It returns an XML NodeSet,
  which is embedded into the output of the XSL.
   
- [claims-with-rules](./claims-with-rules) - an extension object that uses a
  Business Rules engine to process a medical claim. As above, it returns an XML
  NodeSet, which is embedded into the output of the XSL.


## Pre-requisites

- for development, a Linux workstation
- a bash shell
- dotnet 8.0
- [the gcloud cli](https://cloud.google.com/sdk/docs/install-sdk)


## Building the demonstrations

Open a terminal window.

To build each of [circle](./circle), 
 [claims-simple](./claims-simple), and
 [claims-with-rules](./claims-with-rules), cd into the appropriate directory and
 execute `dotnet build`.

To run, execute `dotnet run`.

Each service listens by default on localhost:9090.  Because they all use the
same port, you can run just one of these services at a time on your local
workstation.

## Sending data into the service

You can use the curl command to send a request any of the services.
```sh
curl -i -X POST -H content-type:application/xml \
  ${ENDPOINT}/xml \
  --data-binary @"${randomfile}"
```

The `ENDPOINT` should be 
Use the 



 

