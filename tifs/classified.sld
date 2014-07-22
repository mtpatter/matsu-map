<?xml version="1.0" encoding="ISO-8859-1"?>
<StyledLayerDescriptor version="1.0.0" 
 xsi:schemaLocation="http://www.opengis.net/sld StyledLayerDescriptor.xsd" 
 xmlns="http://www.opengis.net/sld" 
 xmlns:ogc="http://www.opengis.net/ogc" 
 xmlns:xlink="http://www.w3.org/1999/xlink" 
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <NamedLayer>
    <Name>classified color</Name>
    <UserStyle>
      <Title>Classified Color</Title>
      <Abstract>A style for coloring classified images</Abstract>
      <FeatureTypeStyle>
        <Rule>
          <Name>Color Map</Name>
          <Title>Color Table for Classification Numbers</Title>
          <Abstract>Maps from classification numbers to colors representing the classifications</Abstract>
          <RasterSymbolizer>
            <ColorMap type="values">
              <ColorMapEntry color="#000000" quantity="0" label="No Data" opacity="0"/>
              <ColorMapEntry color="#FFFFFF" quantity="1" label="Cloud"/>
              <ColorMapEntry color="#777700" quantity="2" label="Desert"/>
              <ColorMapEntry color="#0000FF" quantity="3" label="Water"/>
              <ColorMapEntry color="#007700" quantity="4" label="Vegetation"/>
            </ColorMap>
          </RasterSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
