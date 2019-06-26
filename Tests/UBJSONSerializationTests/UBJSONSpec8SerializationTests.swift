import XCTest
@testable import UBJSONSerialization



class UBJSONSpec8SerializationTests : XCTestCase {
	
	/* From https://raw.githubusercontent.com/ubjson/universal-binary-json-java/b0f2cbb44ef19357418e41a0813fc498a9eb2779/src/test/resources/org/ubjson/TwitterTimeline.ubj */
	func testDecodeExternalTest1FromGitHub() throws {
		let dataHex = """
		6F157306 69645F73 74727312 31323137 36393138 33383231 33313230 3030730D
		72657477 6565745F 636F756E 74490000 00007317 696E5F72 65706C79 5F746F5F
		73637265 656E5F6E 616D655A 7313696E 5F726570 6C795F74 6F5F7573 65725F69
		645A7309 7472756E 63617465 64467309 72657477 65657465 64467312 706F7373
		69626C79 5F73656E 73697469 76654673 19696E5F 7265706C 795F746F 5F737461
		7475735F 69645F73 74725A73 08656E74 69746965 736F0373 0475726C 736F0473
		0375726C 73146874 74703A5C 5C742E63 6F5C7774 696F4B6B 4653730B 64697370
		6C61795F 75726C73 0D646C76 722E6974 5C705751 79327307 696E6469 63657361
		02490000 00214900 00003573 0C657870 616E6465 645F7572 6C731468 7474703A
		5C5C646C 76722E69 745C7057 51793273 08686173 68746167 73610073 0D757365
		725F6D65 6E74696F 6E736100 73036765 6F5A7305 706C6163 655A730B 636F6F72
		64696E61 7465735A 730A6372 65617465 645F6174 731E5468 75204F63 74203036
		2030323A 31303A31 30202B30 30303020 32303131 7317696E 5F726570 6C795F74
		6F5F7573 65725F69 645F7374 725A7304 75736572 6F267306 69645F73 74727308
		37373032 39303135 73127072 6F66696C 655F6C69 6E6B5F63 6F6C6F72 73063030
		39393939 730A7072 6F746563 74656464 46730375 726C7319 68747470 3A5C5C77
		77772E74 65636864 61792E63 6F2E6E7A 5C730B73 63726565 6E5F6E61 6D657309
		74656368 6461796E 7A730E73 74617475 7365735F 636F756E 74490000 14187311
		70726F66 696C655F 696D6167 655F7572 6C734368 7474703A 5C5C6130 2E747769
		6D672E63 6F6D5C70 726F6669 6C655F69 6D616765 735C3134 37393035 38343038
		5C746563 68646179 5F34385F 6E6F726D 616C2E6A 70677304 6E616D65 73075465
		63684461 79731564 65666175 6C745F70 726F6669 6C655F69 6D616765 46730F64
		65666175 6C745F70 726F6669 6C654673 1870726F 66696C65 5F626163 6B67726F
		756E645F 636F6C6F 72730631 33313531 3673046C 616E6773 02656E73 1770726F
		66696C65 5F626163 6B67726F 756E645F 74696C65 46730A75 74635F6F 66667365
		74490000 A8C0730B 64657363 72697074 696F6E73 00730D69 735F7472 616E736C
		61746F72 46731573 686F775F 616C6C5F 696E6C69 6E655F6D 65646961 46731463
		6F6E7472 69627574 6F72735F 656E6162 6C656446 73227072 6F66696C 655F6261
		636B6772 6F756E64 5F696D61 67655F75 726C5F68 74747073 734F6874 7470733A
		5C5C7369 302E7477 696D672E 636F6D5C 70726F66 696C655F 6261636B 67726F75
		6E645F69 6D616765 735C3735 38393339 34385C54 65636864 61795F42 61636B67
		726F756E 642E6A70 67730A63 72656174 65645F61 74731E54 68752053 65702032
		34203230 3A30323A 3031202B 30303030 20323030 39731A70 726F6669 6C655F73
		69646562 61725F66 696C6C5F 636F6C6F 72730665 66656665 66731366 6F6C6C6F
		775F7265 71756573 745F7365 6E744673 0D667269 656E6473 5F636F75 6E744900
		000C8F73 0F666F6C 6C6F7765 72735F63 6F756E74 4900000C 4D730974 696D655F
		7A6F6E65 73084175 636B6C61 6E647310 6661766F 75726974 65735F63 6F756E74
		49000000 00731C70 726F6669 6C655F73 69646562 61725F62 6F726465 725F636F
		6C6F7273 06656565 65656573 1770726F 66696C65 5F696D61 67655F75 726C5F68
		74747073 73456874 7470733A 5C5C7369 302E7477 696D672E 636F6D5C 70726F66
		696C655F 696D6167 65735C31 34373930 35383430 385C7465 63686461 795F3438
		5F6E6F72 6D616C2E 6A706773 09666F6C 6C6F7769 6E674673 0B67656F 5F656E61
		626C6564 46730D6E 6F746966 69636174 696F6E73 46731C70 726F6669 6C655F75
		73655F62 61636B67 726F756E 645F696D 61676554 730C6C69 73746564 5F636F75
		6E744900 00009773 08766572 69666965 64467312 70726F66 696C655F 74657874
		5F636F6C 6F727306 33333333 33337308 6C6F6361 74696F6E 7316506F 6E736F6E
		62792C20 4175636B 6C616E64 2C204E5A 73026964 4904975E 97731C70 726F6669
		6C655F62 61636B67 726F756E 645F696D 6167655F 75726C73 4D687474 703A5C5C
		61302E74 77696D67 2E636F6D 5C70726F 66696C65 5F626163 6B67726F 756E645F
		696D6167 65735C37 35383933 3934385C 54656368 6461795F 4261636B 67726F75
		6E642E6A 7067730C 636F6E74 72696275 746F7273 5A730673 6F757263 6573333C
		61206872 65663D22 68747470 3A5C5C64 6C76722E 69742220 72656C3D 226E6F66
		6F6C6C6F 77223E64 6C76722E 69743C5C 613E7315 696E5F72 65706C79 5F746F5F
		73746174 75735F69 645A7309 6661766F 72697465 64467302 69644C01 B09C6D72
		42300073 04746578 74733541 70706C65 2043454F 2773206D 65737361 67652074
		6F20656D 706C6F79 65657320 68747470 3A5C5C74 2E636F5C 7774696F 4B6B4653
		"""
		let ref: [String: AnyHashable?] = [
			"id_str": "121769183821312000",
			"retweet_count": 0,
			"in_reply_to_screen_name": nil,
			"in_reply_to_user_id": nil,
			"truncated": false,
			"retweeted": false,
			"possibly_sensitive": false,
			"in_reply_to_status_id_str": nil,
			"entities": [
				"urls": [
					"url": #"http:\\t.co\wtioKkFS"#,
					"display_url": #"dlvr.it\pWQy2"#,
					"indices": [33, 53],
					"expanded_url": #"http:\\dlvr.it\pWQy2"#
				] as [String: AnyHashable?],
				"hashtags": [AnyHashable?](),
				"user_mentions": [AnyHashable?]()
			] as [String: AnyHashable?],
			"geo": nil,
			"place": nil,
			"coordinates": nil,
			"created_at": "Thu Oct 06 02:10:10 +0000 2011",
			"in_reply_to_user_id_str": nil,
			"user": [
				"id_str": "77029015",
				"profile_link_color": "009999",
				"protectedd": false,
				"url": #"http:\\www.techday.co.nz\"#,
				"screen_name": "techdaynz",
				"statuses_count": 5144,
				"profile_image_url": #"http:\\a0.twimg.com\profile_images\1479058408\techday_48_normal.jpg"#,
				"name": "TechDay",
				"default_profile_image": false,
				"default_profile": false,
				"profile_background_color": "131516",
				"lang": "en",
				"profile_background_tile": false,
				"utc_offset": 43200,
				"description": "",
				"is_translator": false,
				"show_all_inline_media": false,
				"contributors_enabled": false,
				"profile_background_image_url_https": #"https:\\si0.twimg.com\profile_background_images\75893948\Techday_Background.jpg"#,
				"created_at": "Thu Sep 24 20:02:01 +0000 2009",
				"profile_sidebar_fill_color": "efefef",
				"follow_request_sent": false,
				"friends_count": 3215,
				"followers_count": 3149,
				"time_zone": "Auckland",
				"favourites_count": 0,
				"profile_sidebar_border_color": "eeeeee",
				"profile_image_url_https": #"https:\\si0.twimg.com\profile_images\1479058408\techday_48_normal.jpg"#,
				"following": false,
				"geo_enabled": false,
				"notifications": false,
				"profile_use_background_image": true,
				"listed_count": 151,
				"verified": false,
				"profile_text_color": "333333",
				"location": "Ponsonby, Auckland, NZ",
				"id": 77029015,
				"profile_background_image_url": #"http:\\a0.twimg.com\profile_background_images\75893948\Techday_Background.jpg"#
			] as [String: AnyHashable?],
			"contributors": nil,
			"source": #"<a href="http:\\dlvr.it" rel="nofollow">dlvr.it<\a>"#,
			"in_reply_to_status_id": nil,
			"favorited": false,
			"id": 121769183821312000,
			"text": #"Apple CEO's message to employees http:\\t.co\wtioKkFS"#
		]
		let data = Data(hexEncoded: dataHex)!
		let decoded = try UBJSONSpec8Serialization.ubjsonObject(with: data)
		/* Interesting note: Comparing decoded with ref returns true, but
		 * comparing the other way around (areUBJSONDocEqual(ref, decoded)) does
		 * not work.
		 * The reason is ref contains only AnyHashable values, and apparently,
		 * AnyHashable(0) as? Bool returns true (actually it does not, but it is
		 * something along those lines; to be tested more thoroughly but it is
		 * certain the problem comes from there). And thus, for the key
		 * retweet_count, the method that compare the UBJSON docs thinks the value
		 * is a bool, and says the docs are not equal because the decoded UBJSON
		 * contains an Int. */
		XCTAssertTrue(try UBJSONSpec8Serialization.areUBJSONDocEqual(decoded, ref))
	}
	
}
