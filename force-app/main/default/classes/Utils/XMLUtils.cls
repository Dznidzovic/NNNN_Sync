/**
 *********************************************************
 * Apex Class Name    : XMLUtils
 * Created Date       : 03-18-2025
 * @description       : Utility class for handling XML parsing operations. This class provides 
 *                      helper methods to extract XML data from SOAP MTOM responses and retrieve 
 *                      specific node values as strings or integers.
 * @author            : Stefan Nidzovic
 * Modification Log:
 * Ver   Date         Author                   Modification
 * 1.0   03-18-2025   Stefan Nidzovic          Initial Version
 *********************************************************
 **/
public with sharing class XMLUtils {

    /**
     *********************************************************
     * @methodName      : extractPureXMLFromMTOM
     * @description     : Extracts pure XML content from a SOAP MTOM response using provided start and end tags.
     * @param startTag  : The opening tag of the XML content to extract.
     * @param endTag    : The closing tag of the XML content to extract.
     * @param mtomResponse : The full SOAP MTOM response containing the XML.
     * @return          : A string containing the extracted XML content or null if the tags are not found.
     *********************************************************
     **/
    public static String extractPureXMLFromMTOM(String startTag, String endTag, String mtomResponse) {
        Integer startIndex = mtomResponse.indexOf(startTag);
        Integer endIndex = mtomResponse.indexOf(endTag) + endTag.length();

        if (startIndex == -1 || endIndex == -1) {
            return null;
        }

        String extractedXml = mtomResponse.substring(startIndex, endIndex);

        return extractedXml;
    }

    /**
     *********************************************************
     * @methodName      : getNodeStringValue
     * @description     : Retrieves the text value of a specified child node within a given XML parent node.
     * @param parentNode : The XML parent node containing the desired child node.
     * @param childName  : The name of the child node whose text value needs to be retrieved.
     * @return          : The text content of the specified child node or null if the node is not found.
     *********************************************************
     **/
    public static String getNodeStringValue(DOM.XmlNode parentNode, String childName) {
        if (parentNode == null) {
            return null;
        }

        DOM.XmlNode childNode = parentNode.getChildElement(childName, parentNode.getNamespace());

        return (childNode != null) ? childNode.getText() : null;
    }

    /**
     *********************************************************
     * @methodName      : getNodeIntegerValue
     * @description     : Retrieves the integer value of a specified child node within a given XML parent node.
     * @param parentNode : The XML parent node containing the desired child node.
     * @param childName  : The name of the child node whose integer value needs to be retrieved.
     * @return          : The integer value of the specified child node or null if the node is not found or non-numeric.
     *********************************************************
     **/
    public static Integer getNodeIntegerValue(DOM.XmlNode parentNode, String childName) {
        String value = getNodeStringValue(parentNode, childName);

        return (value != null && value.isNumeric()) ? Integer.valueOf(value) : null;
    }

    /**
     *********************************************************
     * @methodName      : getNodeBooleanValue
     * @description     : Retrieves the boolean value of a specified child node within a given XML parent node.
     * @param parentNode : The XML parent node containing the desired child node.
     * @param childName  : The name of the child node whose boolean value needs to be retrieved.
     * @return          : The boolean value of the specified child node (true/false) or null if the node is not found.
     *********************************************************
     **/
    public static Boolean getNodeBooleanValue(DOM.XmlNode parentNode, String childName) {
        String value = getNodeStringValue(parentNode, childName);
        
        if (value == null) {
            return null;
        }
        
        value = value.trim().toLowerCase();
       
        return Boolean.valueOf(value);
    }

    /**
     *********************************************************
     * @methodName      : convertXMLToMap
     * @source          : https://medium.com/@nikeshvarma/effortless-xml-parsing-in-salesforce-apex-e391b49ca362
     * @description     : Recursively parses a DOM.XmlNode and builds a hierarchical 
     *                    Map<String, Object> structure that represents the original XML.
     *                    Attributes are stored under the 'attributes' key. If a node 
     *                    contains only text (no children, no attributes), it's stored 
     *                    directly as a string. Otherwise, its nested children are recursively 
     *                    added to the structure.
     * @param           : xmlNode - The root XML node to process.
     * @param           : jsonData - The output map that will contain the parsed structure.
     *********************************************************
     **/
    public static void convertXMLToMap(Dom.XmlNode xmlNode, Map<String, Object> jsonData) {
        for (Dom.XmlNode childNode : xmlNode.getChildElements()) {
            Map<String, Object> childMap = new Map<String, Object>();
            Map<String, String> attrMap = new Map<String, String>();

            // Extract all attributes into attrMap
            for (Integer i = 0; i < childNode.getAttributeCount(); i++) {
                String attrName = childNode.getAttributeKeyAt(i);
                String attrNs = childNode.getAttributeKeyNsAt(i);
                String attrVal = childNode.getAttributeValue(attrName, attrNs);
                attrMap.put(attrName, attrVal);
            }

            Boolean hasAttributes = !attrMap.isEmpty();
            Boolean hasChildren = !childNode.getChildElements().isEmpty();
            String text = childNode.getText().trim();

            Object toStore;

            if (!hasAttributes && !hasChildren) {
                // Store plain text value directly
                toStore = text;
            } else {
                // Store attributes if present
                if (hasAttributes) {
                    childMap.put('attributes', attrMap);
                }

                // Recurse into child elements if present
                if (hasChildren) {
                    convertXMLToMap(childNode, childMap);
                }

                // Final object to store is the full childMap
                toStore = childMap;
            }

            String tag = childNode.getName();

            // If the tag already exists, convert to or append to a list
            if (jsonData.containsKey(tag)) {
                Object existing = jsonData.get(tag);

                if (existing instanceof List<Object>) {
                    ((List<Object>) existing).add(toStore);
                } else {
                    jsonData.put(tag, new List<Object>{ existing, toStore });
                }
            } else {
                jsonData.put(tag, toStore);
            }
        }
    }
    
    /**
     *********************************************************
     * @methodName      : filterCarrierAppointments
     * @description     : Removes all APPOINTMENT_INFORMATION nodes and their children from XML response
     *                    to reduce payload size for large producers. Uses memory-efficient approach
     *                    to avoid heap size issues with large payloads.
     * @param xmlResponse : The XML response string containing APPOINTMENT_INFORMATION nodes
     * @return          : XML string with all APPOINTMENT_INFORMATION nodes completely removed
     *********************************************************
     **/
    public static String filterCarrierAppointments(String xmlResponse) {
        String openTag = '<APPOINTMENT_INFORMATION';
        String closeTag = '</APPOINTMENT_INFORMATION>';
        
        // Build result by collecting parts we want to keep
        List<String> parts = new List<String>();
        Integer currentPos = 0;
        
        while (true) {
            Integer startIndex = xmlResponse.indexOf(openTag, currentPos);
            
            // No more APPOINTMENT_INFORMATION sections found
            if (startIndex == -1) {
                // Add the remaining part
                if (currentPos < xmlResponse.length()) {
                    parts.add(xmlResponse.substring(currentPos));
                }
                break;
            }
            
            // Add the part before this APPOINTMENT_INFORMATION section
            if (startIndex > currentPos) {
                parts.add(xmlResponse.substring(currentPos, startIndex));
            }
            
            // Find the end of the opening tag (could have attributes)
            Integer openTagEnd = xmlResponse.indexOf('>', startIndex);
            if (openTagEnd == -1) {
                break;
            }
            
            // Find the matching closing tag
            Integer endIndex = xmlResponse.indexOf(closeTag, openTagEnd);
            if (endIndex == -1) {
                break;
            }
            
            // Skip past the closing tag
            currentPos = endIndex + closeTag.length();
        }
        
        // Join all parts - this is more memory efficient than repeated substring concatenation
        return String.join(parts, '');
    }
}