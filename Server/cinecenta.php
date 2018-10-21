<?php

//	Scrape the www.cinecenta.com site and put together a simple SJON structure listing today's
//	and tomorrow's movies:
//
//	{
//		"today": [
//	    	{
//	    	    "title": "ANTHROPOCENE: The Human Epoch",
//	    	    "times": "Oct 16, 17 & 18 7:00 & 9:00 pm",
//	    	    "href": "default.aspx?PageID=1005&MovieID=1602",
//	    	    "image": "\/images\/movies\/1602\/image2.jpg"
//	    	}
//		],
//		"tomorrow": [
//	    	{
//	        	"title": "ANTHROPOCENE: The Human Epoch",
//	        	"times": "Oct 16, 17 & 18 7:00 & 9:00 pm",
//	        	"href": "default.aspx?PageID=1005&MovieID=1602",
//	        	"image": "\/images\/movies\/1602\/image2.jpg"
//	    	}
//		]
//	}

/* Use internal libxml errors -- turn on in production, off for debugging */
libxml_use_internal_errors(true);

//	Because my hosting provider has allow_url_fopen turned off, I have to resort to workarounds...

function readFromURL($url) {
	if (function_exists('curl_version'))
	{
		$curl = curl_init();
		curl_setopt($curl, CURLOPT_URL, $url);
		curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
		$content = curl_exec($curl);
		curl_close($curl);
	}
	else if (file_get_contents(__FILE__) && ini_get('allow_url_fopen'))
	{
		$content = file_get_contents($url);
	}
	else
	{
		trigger_error('You have neither cUrl installed nor allow_url_fopen activated. Please setup one of those!');
	}
	
	return $content;
}

function innerHTML(DOMNode $element)  { 
    $innerHTML = ""; 
    $children  = $element->childNodes;

    foreach ($children as $child) { 
        $innerHTML .= $element->ownerDocument->saveHTML($child);
    }

    return $innerHTML; 
} 


$url = 'https://www.cinecenta.com';
$dom = new DomDocument;
//$dom->loadHTMLFile($url);
$dom->loadHTML(readFromURL($url));
$xpath = new DomXPath($dom);

$today = $xpath->query("//div[contains(@class, 'clsMoviesPlayingToday')]")->item(0);
$tomorrow = $xpath->query("//div[contains(@class, 'clsMoviesPlayingTomorrow')]")->item(0);
$result = [];

function getDay($xpath, $day) {
	global $url;
	
	$nodes = $xpath->query(".//div[contains(@class, 'clsTitle')]", $day);
	$result = array_fill(0, count($nodes), []);
	
	foreach ($nodes as $i => $node) {
		$result[$i]['title'] = trim($node->nodeValue);
	}
	
	$nodes = $xpath->query(".//div[contains(@class, 'clsTimes')]", $day);
	foreach ($nodes as $i => $node) {
		$result[$i]['times'] = trim(str_replace("<br>", "\n", html_entity_decode(innerHTML($node))) /*$node->nodeValue*/);
	}

	$nodes = $xpath->query(".//div[contains(@class, 'clsImageContainer')]/a/@href", $day);
	foreach ($nodes as $i => $node) {
		$result[$i]['href'] = $url . '/' . trim($node->nodeValue);
	}

	$nodes = $xpath->query(".//div[contains(@class, 'clsImageContainer')]/a/img/@src", $day);
	foreach ($nodes as $i => $node) {
		$result[$i]['image'] = $url . trim($node->nodeValue);
	}
    
    //error_log(print_r($result, true));
    return $result;
}


$result['today'] = getDay($xpath, $today);
$result['tomorrow'] = getDay($xpath, $tomorrow);

header("Content-type: application/json");
if (true)
	echo json_encode($result, JSON_PRETTY_PRINT);
else
	echo json_encode($result, 0);
