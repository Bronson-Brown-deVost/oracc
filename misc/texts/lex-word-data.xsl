<?xml version='1.0'?>
<xsl:stylesheet version="1.0" 
		xmlns:xcl="http://oracc.org/ns/xcl/1.0"
		xmlns:xff="http://oracc.org/ns/xff/1.0"
		xmlns:lex="http://oracc.org/ns/lex/1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		exclude-result-prefixes="xcl xff">

<xsl:template match="/">
  <lex:text>
    <xsl:apply-templates select=".//xcl:c[@type='sentence']"/>
  </lex:text>
</xsl:template>

<xsl:template match="xcl:c[@type='sentence']">
  <xsl:choose>
    <xsl:when test="xcl:d[@type='field-start']">
      <xsl:if test="xcl:d[@subtype='wp']|xcl:d[@subtype='sv']">
	<lex:data>
	  <xsl:call-template name="lex-data-meta"/>
	  <xsl:attribute name="sref">
	    <xsl:value-of select="xcl:l[preceding-sibling::xcl:d[@type='field-start'][1][@subtype='sg']]/@ref"/>
	  </xsl:attribute>
	  <xsl:attribute name="sign">
	    <xsl:value-of select="xcl:l[preceding-sibling::xcl:d[@type='field-start'][1][@subtype='sg']]/xff:f/@form"/>
	  </xsl:attribute>
	  <xsl:attribute name="read">
	    <xsl:value-of select="xcl:l[preceding-sibling::xcl:d[@type='field-start'][1][@subtype='sv']]/xff:f/@form"/>
	  </xsl:attribute>
	  <xsl:attribute name="spel">
	    <xsl:value-of select="xcl:l[preceding-sibling::xcl:d[@type='field-start'][1][@subtype='pr']]/xff:f/@form"/>
	  </xsl:attribute>
	  <xsl:call-template name="get-words">
	    <xsl:with-param name="type" select="'sv'"/>
	  </xsl:call-template>
	  <xsl:call-template name="get-words">
	    <xsl:with-param name="type" select="'wp'"/>
	  </xsl:call-template>
	  <xsl:call-template name="get-words">
	    <xsl:with-param name="type" select="'eq'"/>
	  </xsl:call-template>
	</lex:data>
      </xsl:if>
    </xsl:when>
    <xsl:otherwise>
      <xsl:for-each select="xcl:d[@type='line-start']">
	<xsl:call-template name="get-words-l">
	  <xsl:with-param name="ref" select="@ref"/>
	</xsl:call-template>
      </xsl:for-each>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="get-words">
  <xsl:param name="type"/>
  <xsl:for-each select="xcl:d[@type='field-start'][@subtype=$type]">
    <xsl:call-template name="get-words-one">
      <xsl:with-param name="type" select="$type"/>
      <xsl:with-param name="nth" select="position()"/>
    </xsl:call-template>
  </xsl:for-each>
</xsl:template>

<xsl:template name="get-words-one">
  <xsl:param name="type"/>
  <xsl:param name="nth"/>
  <!--
      <xsl:message>type=<xsl:value-of select="$type"
      />; nth=<xsl:value-of select="$nth"/></xsl:message> -->
  <xsl:variable name="f-start">
    <xsl:for-each select="../xcl:d[@type='field-start'][@subtype=$type][$nth]">
      <xsl:value-of select="count(preceding-sibling::*)+1"/>
    </xsl:for-each>
  </xsl:variable>
  <xsl:variable name="f-top" select="count(../*)+1"/>
  <xsl:variable name="f-end">
    <xsl:choose>
      <xsl:when test="../xcl:d[@type='field-end'][@subtype=$type][$nth]">
	<xsl:for-each select="../xcl:d[@type='field-end'][@subtype=$type][$nth]">
	  <xsl:value-of select="count(preceding-sibling::*)+1"/>
	</xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="$f-top"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <!--
      <xsl:message><xsl:value-of select="$type"
      /> start=<xsl:value-of select="$f-start"
      />; end=<xsl:value-of select="$f-end"/></xsl:message> -->
  <xsl:if test="$f-start > 0">
    <xsl:element name="lex:{$type}">
      <xsl:for-each select="../*[position()>$f-start and position()&lt;$f-end]">
	<xsl:call-template name="lex-word"/>
      </xsl:for-each>
    </xsl:element>
  </xsl:if>
</xsl:template>

<xsl:template name="get-words-l">
  <xsl:param name="ref"/>
  <xsl:variable name="l-start">
    <xsl:for-each select="../xcl:d[@type='line-start'][@ref=$ref]">
      <xsl:value-of select="count(preceding-sibling::*)+1"/>
    </xsl:for-each>
  </xsl:variable>
  <xsl:variable name="l-top" select="count(../*)+1"/>
  <xsl:variable name="l-end">
    <xsl:for-each select="../xcl:d[@type='line-start'][@ref=$ref]">
      <xsl:choose>
	<xsl:when test="following-sibling::*[@type='line-start'][1]">
	  <xsl:for-each select="following-sibling::*[@type='line-start'][1]">
	    <xsl:value-of select="count(preceding-sibling::*)+1"/>
	  </xsl:for-each>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:value-of select="$l-top"/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:variable>
  <!--
      <xsl:message><xsl:value-of select="concat('line@',$ref)"
      /> start=<xsl:value-of select="$l-start"
      />; end=<xsl:value-of select="$l-end"/></xsl:message>-->
  <lex:data>
    <xsl:call-template name="lex-data-meta"/>
    <lex:wp>
      <xsl:for-each select="../*[position()>$l-start and position()&lt;$l-end]">
	<xsl:if test="self::xcl:l">
	  <xsl:call-template name="lex-word"/>
	</xsl:if>
      </xsl:for-each>
    </lex:wp>
  </lex:data>
</xsl:template>

<xsl:template name="lex-word">
  <xsl:if test="self::xcl:l">
    <lex:word>
      <xsl:attribute name="wref"><xsl:value-of select="@ref"/></xsl:attribute>
      <xsl:attribute name="form"><xsl:value-of select="xff:f/@form"/></xsl:attribute>
      <xsl:attribute name="lang"><xsl:value-of select="xff:f/@xml:lang"/></xsl:attribute>
      <xsl:if test="string-length(xff:f/@cf)>0">
	<xsl:attribute name="cfgw"><xsl:value-of select="concat(xff:f/@cf,'[',xff:f/@gw,']',xff:f/@pos)"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="xff:f/@base">
	<xsl:attribute name="base"><xsl:value-of select="xff:f/@base"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="xff:f/@norm">
	<xsl:attribute name="norm"><xsl:value-of select="xff:f/@norm"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="xff:f/@sense">
	<xsl:attribute name="sense"><xsl:value-of select="xff:f/@sense"/></xsl:attribute>
      </xsl:if>
    </lex:word>
  </xsl:if>
</xsl:template>

<xsl:template name="lex-data-meta">
  <xsl:copy-of select="/*/@project"/>
  <xsl:attribute name="id_text">
    <xsl:value-of select="/*/@xml:id"/>
  </xsl:attribute>
  <xsl:copy-of select="/*/@n"/>
  <xsl:copy-of select="@xml:id"/>
  <xsl:copy-of select="@label"/>
</xsl:template>

</xsl:stylesheet>