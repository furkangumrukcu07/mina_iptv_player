import random

def generate_m3u():
    header = '#EXTM3U x-tvg-url="https://iptv-org.github.io/epg/guides/tr.xml"\n\n'
    
    # --- 50 CANLI YAYIN (Legal Public Channels) ---
    live_channels = [
        ("NASA TV", "https://upload.wikimedia.org/wikipedia/commons/e/eb/NASA_logo.svg", "https://ntvcp1.akamaized.net/hls/live/2029044/NASA-NTV1-Public/master.m3u8"),
        ("DW English", "https://upload.wikimedia.org/wikipedia/commons/d/d1/Deutsche_Welle_logo.svg", "https://dwamdstream102.akamaized.net/hls/live/2015415/dwstream102/index.m3u8"),
        ("France 24", "https://upload.wikimedia.org/wikipedia/commons/b/b1/France_24_logo.svg", "https://static.france24.com/live/f24_en.error/playlist.m3u8"),
        ("Al Jazeera", "https://upload.wikimedia.org/wikipedia/en/2/2d/Al_Jazeera_Logo.png", "https://live-hls-web-aja.getaj.net/AJA/index.m3u8"),
        ("Bloomberg TV", "https://upload.wikimedia.org/wikipedia/commons/5/5d/Bloomberg_Television_Logo.png", "https://www.bloomberg.com/media-manifest/streams/us.m3u8"),
        ("Cheddar News", "https://upload.wikimedia.org/wikipedia/commons/0/0a/Cheddar_logo.svg", "https://live.chdrmedia.com/cheddartv/index.m3u8"),
        ("CBS News", "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/CBS_News_logo.svg/512px-CBS_News_logo.svg.png", "https://cbsn-us.cbsnstream.cbsnews.com/out/v1/c4b387c1e67f40b2b77af42e2f09aa31/master.m3u8"),
        ("EuroNews", "https://upload.wikimedia.org/wikipedia/commons/thumb/3/39/Euronews_2016_logo.svg/512px-Euronews_2016_logo.svg.png", "https://euronews.alteox.app/hls/en_stream.m3u8"),
        ("NASA TV Media", "https://upload.wikimedia.org/wikipedia/commons/e/eb/NASA_logo.svg", "https://ntvcp2.akamaized.net/hls/live/2029045/NASA-NTV2-Media/master.m3u8"),
        ("United Nations", "https://upload.wikimedia.org/wikipedia/commons/2/2a/United_Nations_logo.svg", "https://cdnapi.kaltura.com/p/2503451/sp/250345100/playManifest/entryId/1_gb6tjmbe/format/applehttp.m3u8"),
        ("TV5 Monde", "https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/TV5Monde_logo.svg/512px-TV5Monde_logo.svg.png", "https://ott.tv5monde.com/Content/HLS/Live/channel(info)/index.m3u8"),
        ("TRT World", "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/TRT_World_logo.svg/512px-TRT_World_logo.svg.png", "https://tv-trtworld.live.trt.com.tr/master.m3u8"),
        ("ABC News", "https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/ABC_News_Logo_2021.svg/512px-ABC_News_Logo_2021.svg.png", "https://content.uplynk.com/channel/3324f2467c414329b3b0cc5cd987b6be.m3u8"),
        ("PBS America", "https://upload.wikimedia.org/wikipedia/en/thumb/5/55/PBS_America_logo.svg/512px-PBS_America_logo.svg.png", "https://pbs-samsunguk.amagi.tv/playlist.m3u8"),
        ("Red Bull TV", "https://upload.wikimedia.org/wikipedia/en/thumb/9/98/Red_Bull_TV_logo.svg/512px-Red_Bull_TV_logo.svg.png", "https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8"),
        ("Rakuten Action", "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Rakuten_TV_logo.svg/512px-Rakuten_TV_logo.svg.png", "https://rakuten-action-1-eu.rakuten.wurl.tv/playlist.m3u8"),
        ("Rakuten Comedy", "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Rakuten_TV_logo.svg/512px-Rakuten_TV_logo.svg.png", "https://rakuten-comedy-1-eu.rakuten.wurl.tv/playlist.m3u8"),
        ("Rakuten Drama", "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Rakuten_TV_logo.svg/512px-Rakuten_TV_logo.svg.png", "https://rakuten-drama-1-eu.rakuten.wurl.tv/playlist.m3u8"),
        ("Rakuten Family", "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Rakuten_TV_logo.svg/512px-Rakuten_TV_logo.svg.png", "https://rakuten-family-1-eu.rakuten.wurl.tv/playlist.m3u8"),
        ("Rakuten Top Free", "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Rakuten_TV_logo.svg/512px-Rakuten_TV_logo.svg.png", "https://rakuten-topfree-1-eu.rakuten.wurl.tv/playlist.m3u8"),
        ("BBC World Service", "https://upload.wikimedia.org/wikipedia/en/thumb/6/63/BBC_World_Service.svg/512px-BBC_World_Service.svg.png", "https://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_low/ak/bbc_world_service.m3u8"),
        ("Canadian Parliament", "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Parliament_of_Canada_Logo.svg/512px-Parliament_of_Canada_Logo.svg.png", "https://cdn4.senato.it/live/senato/hls/aac/test_aac_25/playlist.m3u8"),
        ("Australian Parliament", "https://upload.wikimedia.org/wikipedia/en/thumb/a/a3/Parliament_of_Australia_Logo.svg/512px-Parliament_of_Australia_Logo.svg.png", "https://d1kexqsrd8d8sl.cloudfront.net/austparl_meet_1@363112/master.m3u8"),
        ("Taiwan Plus", "https://upload.wikimedia.org/wikipedia/en/thumb/a/a9/Taiwan_Plus_logo.svg/512px-Taiwan_Plus_logo.svg.png", "https://bcovlive-a.akamaihd.net/rce33d41cb7d94cc59cd05bc634f43138/us-west-2/5816339219001/playlist.m3u8"),
        ("Vancouver City", "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Vancouver_CoA.svg/512px-Vancouver_CoA.svg.png", "https://cdn3.wowza.com/5/cHYzekQyM2Q2N2tB/cityofvancouver/G0164_003/playlist.m3u8"),
        ("Classic Arts Showcase", "https://upload.wikimedia.org/wikipedia/en/thumb/3/34/Classic_Arts_Showcase_logo.svg/512px-Classic_Arts_Showcase_logo.svg.png", "https://classicarts.akamaized.net/hls/live/1024257/MUS.m3u8"),
        ("CBC News", "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/CBC_News_Logo.svg/512px-CBC_News_Logo.svg.png", "https://cbcrclinear-tor.akamaized.net/hls/live/2042760/CBCRCLINEAR_TOR_15/master.m3u8"),
        ("TVE Internacional", "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/TVE_Internacional_logo_2021.svg/512px-TVE_Internacional_logo_2021.svg.png", "https://rtvelivestream.akamaized.net/rtvesec/int/tvei_int.m3u8"),
        ("RAI Italia", "https://upload.wikimedia.org/wikipedia/commons/thumb/0/01/RAI_Italia_logo.svg/512px-RAI_Italia_logo.svg.png", "https://rainews1-live.akamaized.net/hls/live/598326/rainews1/rainews1/playlist.m3u8"),
        ("Deutsche Welle Español", "https://upload.wikimedia.org/wikipedia/commons/d/d1/Deutsche_Welle_logo.svg", "https://dwamdstream104.akamaized.net/hls/live/2015530/dwstream104/index.m3u8"),
        ("CGTN Français", "https://upload.wikimedia.org/wikipedia/commons/thumb/8/83/CGTN_Logo.svg/512px-CGTN_Logo.svg.png", "https://news.cgtn.com/resource/live/french/cgtn-f.m3u8"),
        ("CGTN Español", "https://upload.wikimedia.org/wikipedia/commons/thumb/8/83/CGTN_Logo.svg/512px-CGTN_Logo.svg.png", "https://news.cgtn.com/resource/live/espanol/cgtn-e.m3u8"),
        ("CGTN Documentary", "https://upload.wikimedia.org/wikipedia/commons/thumb/8/83/CGTN_Logo.svg/512px-CGTN_Logo.svg.png", "https://news.cgtn.com/resource/live/document/cgtn-doc.m3u8"),
        ("WGN News", "https://upload.wikimedia.org/wikipedia/en/thumb/0/0f/WGN_America_2021_logo.svg/512px-WGN_America_2021_logo.svg.png", "https://wgn9news-8p2jfedj.wifi8997.com/wgn9n2/news.m3u8"),
        ("KEXP Radio", "https://upload.wikimedia.org/wikipedia/en/thumb/6/62/KEXP_logo.svg/512px-KEXP_logo.svg.png", "https://kexp.streamguys1.com/kexp320.mp3.m3u"),
        ("Radio Swiss Classic", "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Logo_Radio_Swiss_Classic.svg/512px-Logo_Radio_Swiss_Classic.svg.png", "https://stream.srg-ssr.ch/m/rsc_de/mp3_128"),
        ("Radio Swiss Jazz", "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Logo_Radio_Swiss_Jazz.svg/512px-Logo_Radio_Swiss_Jazz.svg.png", "https://stream.srg-ssr.ch/m/rsj/mp3_128"),
        ("Ibiza Global Radio", "https://upload.wikimedia.org/wikipedia/en/thumb/2/22/Ibiza_Global_Radio_logo.svg/512px-Ibiza_Global_Radio_logo.svg.png", "https://ibizaglobalradio.streaming-pro.com:3060/128.m3u8"),
        ("FIP Radio", "https://upload.wikimedia.org/wikipedia/en/thumb/9/9e/FIP_logo.svg/512px-FIP_logo.svg.png", "https://direct.fipradio.fr/live/fip-midfi.mp3?ID=radiofrance"),
        ("NTS Radio", "https://upload.wikimedia.org/wikipedia/en/thumb/0/0f/NTS_Radio_logo.svg/512px-NTS_Radio_logo.svg.png", "https://stream-relay-geo.ntslive.net/stream"),
        ("Box Plus", "https://upload.wikimedia.org/wikipedia/en/thumb/5/5e/Box_Plus_Network_logo.svg/512px-Box_Plus_Network_logo.svg.png", "https://csm-e-boxplus.tls1.yospace.com/csm/extlive/boxplus01,boxplus_network01.m3u8"),
        ("KDFW Fox 4", "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/FOX_wordmark.svg/512px-FOX_wordmark.svg.png", "https://d1lv1lpzlrjn3g.cloudfront.net/out/v1/ea0a5d2c4c974a27be47186409db95a4/index.m3u8"),
        ("WPLG Local 10", "https://upload.wikimedia.org/wikipedia/en/thumb/3/34/Local_10_WPLG_logo.svg/512px-Local_10_WPLG_logo.svg.png", "https://videos2.outcomeviewer.com/6b/c5/bfa7d99b4a59c05f43d46c73767b064c/playlist.m3u8"),
        ("Weather Nation", "https://upload.wikimedia.org/wikipedia/en/thumb/a/a6/WeatherNation_TV_logo.svg/512px-WeatherNation_TV_logo.svg.png", "https://cdn.klowdtv.net/803B48A/n1euWE4g.m3u8"),
        ("i24 News", "https://upload.wikimedia.org/wikipedia/en/thumb/7/7c/I24_News_logo.svg/512px-I24_News_logo.svg.png", "https://bcovlive-a.akamaihd.net/6e3dd61ac4c34d3f8d441b8f17a88c8a/us-east-1/5377161796001/playlist.m3u8"),
        ("BEK TV", "https://upload.wikimedia.org/wikipedia/en/thumb/7/7b/BEK_TV_logo.svg/512px-BEK_TV_logo.svg.png", "https://cdn.bek.tv/be.m3u8"),
        ("Sofa TV", "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Sofa_Tv_logo.svg/512px-Sofa_Tv_logo.svg.png", "https://admin.sofatv.com/hls/stream/index.m3u8"),
        ("Earth TV", "https://upload.wikimedia.org/wikipedia/commons/thumb/3/39/Earth_from_Space.svg/512px-Earth_from_Space.svg.png", "https://livecdn-de-earthtv-com.webcdn.stream/edge/sd/fluxus/index.m3u8"),
        ("Venice Live", "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Venice_Logo.svg/512px-Venice_Logo.svg.png", "https://radiotv-lrt.akamaized.net/live/stream.m3u8"),
    ]
    
    # --- 50 FİLM (Public Domain Classics) ---
    movies = [
        ("Sita Sings the Blues", "7.6", "2008", "Annette Hanshaw", "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Sita_Sings_the_Blues_poster.jpg/800px-Sita_Sings_the_Blues_poster.jpg"),
        ("Night of the Living Dead", "7.8", "1968", "Duane Jones, Judith O'Dea", "https://upload.wikimedia.org/wikipedia/commons/3/3d/Night_of_the_Living_Dead_poster.jpg"),
        ("The General", "8.1", "1926", "Buster Keaton", "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/The_General_1926_poster.jpg/800px-The_General_1926_poster.jpg"),
        ("Nosferatu", "7.9", "1922", "Max Schreck", "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/NosferatuPoster.jpg/800px-NosferatuPoster.jpg"),
        ("Metropolis", "8.3", "1927", "Brigitte Helm, Alfred Abel", "https://upload.wikimedia.org/wikipedia/commons/3/36/Metropolis_%281927_poster%29.jpg"),
        ("The Cabinet of Dr. Caligari", "8.0", "1920", "Werner Krauss", "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/The_Cabinet_of_Dr._Caligari_poster.jpg/800px-The_Cabinet_of_Dr._Caligari_poster.jpg"),
        ("Sunrise: A Song of Two Humans", "8.1", "1927", "George O'Brien", "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b2/Sunrise_-_A_Song_of_Two_Humans_poster.jpg/800px-Sunrise_-_A_Song_of_Two_Humans_poster.jpg"),
        ("The Phantom of the Opera", "7.6", "1925", "Lon Chaney", "https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Phantom_of_the_Opera_%281925_film%29.jpg/800px-Phantom_of_the_Opera_%281925_film%29.jpg"),
        ("The Gold Rush", "8.2", "1925", "Charlie Chaplin", "https://upload.wikimedia.org/wikipedia/commons/thumb/0/01/The_Gold_Rush_poster.jpg/800px-The_Gold_Rush_poster.jpg"),
        ("Modern Times", "8.5", "1936", "Charlie Chaplin", "https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Modern_Times_poster.jpg/800px-Modern_Times_poster.jpg"),
        ("The Great Dictator", "8.4", "1940", "Charlie Chaplin", "https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/The_Great_Dictator_%281940%29_poster.jpg/800px-The_Great_Dictator_%281940%29_poster.jpg"),
        ("Reefer Madness", "3.7", "1936", "Dorothy Short", "https://upload.wikimedia.org/wikipedia/commons/thumb/8/86/Reefer_Madness_%281936%29_poster.jpg/800px-Reefer_Madness_%281936%29_poster.jpg"),
        ("Carnival of Souls", "7.1", "1962", "Candace Hilligoss", "https://upload.wikimedia.org/wikipedia/commons/thumb/5/50/Carnival_of_Souls_poster.jpg/800px-Carnival_of_Souls_poster.jpg"),
        ("House on Haunted Hill", "6.9", "1959", "Vincent Price", "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/House_on_Haunted_Hill_poster.jpg/800px-House_on_Haunted_Hill_poster.jpg"),
        ("The Last Time I Saw Paris", "6.6", "1954", "Elizabeth Taylor", "https://upload.wikimedia.org/wikipedia/en/thumb/2/2c/The_Last_Time_I_Saw_Paris.jpg/800px-The_Last_Time_I_Saw_Paris.jpg"),
        ("A Star is Born", "7.3", "1937", "Janet Gaynor", "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e2/A_Star_is_Born_1937_poster.jpg/800px-A_Star_is_Born_1937_poster.jpg"),
        ("His Girl Friday", "7.8", "1940", "Cary Grant, Rosalind Russell", "https://upload.wikimedia.org/wikipedia/commons/thumb/5/58/His_Girl_Friday_%281940%29_1.jpg/800px-His_Girl_Friday_%281940%29_1.jpg"),
        ("The Man Who Knew Too Much", "6.9", "1934", "Leslie Banks", "https://upload.wikimedia.org/wikipedia/en/thumb/3/35/Man_Who_Knew_Too_Much_%281934%29.jpg/800px-Man_Who_Knew_Too_Much_%281934%29.jpg"),
        ("The 39 Steps", "7.6", "1935", "Robert Donat", "https://upload.wikimedia.org/wikipedia/en/thumb/7/75/The_39_Steps_1935.jpg/800px-The_39_Steps_1935.jpg"),
        ("My Man Godfrey", "8.0", "1936", "William Powell, Carole Lombard", "https://upload.wikimedia.org/wikipedia/en/thumb/d/dc/My_Man_Godfrey_poster.jpg/800px-My_Man_Godfrey_poster.jpg"),
        ("The Lady Vanishes", "7.8", "1938", "Margaret Lockwood", "https://upload.wikimedia.org/wikipedia/en/thumb/e/e4/The_Lady_Vanishes_%281938_film%29.jpg/800px-The_Lady_Vanishes_%281938_film%29.jpg"),
        ("D.O.A.", "7.3", "1950", "Edmond O'Brien", "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Poster_-_D.O.A._%281950%29_01.jpg/800px-Poster_-_D.O.A._%281950%29_01.jpg"),
        ("The Hitch-Hiker", "7.0", "1953", "Edmond O'Brien", "https://upload.wikimedia.org/wikipedia/en/thumb/f/f3/The_Hitch-Hiker_%281953_film%29.jpg/800px-The_Hitch-Hiker_%281953_film%29.jpg"),
        ("Detour", "7.4", "1945", "Tom Neal", "https://upload.wikimedia.org/wikipedia/en/thumb/6/69/Detour_%281945_film%29.jpg/800px-Detour_%281945_film%29.jpg"),
        ("Scarlet Street", "7.7", "1945", "Edward G. Robinson", "https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Scarlet_Street_poster.jpg/800px-Scarlet_Street_poster.jpg"),
        ("Fear and Desire", "5.4", "1953", "Frank Silvera", "https://upload.wikimedia.org/wikipedia/en/thumb/7/77/Fear_and_Desire_poster.jpg/800px-Fear_and_Desire_poster.jpg"),
        ("The Immigrant", "7.7", "1917", "Charlie Chaplin", "https://upload.wikimedia.org/wikipedia/en/thumb/c/c3/The_Immigrant_%281917_film%29.jpg/800px-The_Immigrant_%281917_film%29.jpg"),
        ("The Kid", "8.3", "1921", "Charlie Chaplin, Jackie Coogan", "https://upload.wikimedia.org/wikipedia/commons/thumb/5/51/The_Kid_%281921%29_poster.jpg/800px-The_Kid_%281921%29_poster.jpg"),
        ("Shoulder Arms", "7.3", "1918", "Charlie Chaplin", "https://upload.wikimedia.org/wikipedia/en/thumb/5/5e/Shoulder_Arms.jpg/800px-Shoulder_Arms.jpg"),
        ("The Lodger", "7.3", "1927", "Ivor Novello", "https://upload.wikimedia.org/wikipedia/en/thumb/9/9e/The_Lodger_1927.jpg/800px-The_Lodger_1927.jpg"),
        ("Blackmail", "7.0", "1929", "Anny Ondra", "https://upload.wikimedia.org/wikipedia/en/thumb/a/a3/Blackmail_%281929_film%29.jpg/800px-Blackmail_%281929_film%29.jpg"),
        ("The 39 Steps", "7.6", "1935", "Robert Donat", "https://upload.wikimedia.org/wikipedia/en/thumb/7/75/The_39_Steps_1935.jpg/800px-The_39_Steps_1935.jpg"),
        ("Secret Agent", "6.5", "1936", "Peter Lorre", "https://upload.wikimedia.org/wikipedia/en/thumb/3/3e/Secret_Agent_1936.jpg/800px-Secret_Agent_1936.jpg"),
        ("Saboteur", "7.2", "1942", "Robert Cummings", "https://upload.wikimedia.org/wikipedia/en/thumb/8/85/Saboteur_1942.jpg/800px-Saboteur_1942.jpg"),
        ("Shadow of a Doubt", "7.8", "1943", "Joseph Cotten", "https://upload.wikimedia.org/wikipedia/en/thumb/a/a1/Shadow_of_a_Doubt_%281943_movie_poster%29.jpg/800px-Shadow_of_a_Doubt_%281943_movie_poster%29.jpg"),
        ("Lifeboat", "7.6", "1944", "Tallulah Bankhead", "https://upload.wikimedia.org/wikipedia/en/thumb/d/de/Lifeboat_%28Alfred_Hitchcock%29_poster.jpg/800px-Lifeboat_%28Alfred_Hitchcock%29_poster.jpg"),
        ("Spellbound", "7.5", "1945", "Gregory Peck", "https://upload.wikimedia.org/wikipedia/en/thumb/4/44/Spellbound_1945.jpg/800px-Spellbound_1945.jpg"),
        ("Notorious", "7.9", "1946", "Cary Grant, Ingrid Bergman", "https://upload.wikimedia.org/wikipedia/en/thumb/3/39/Notorious_film_poster.jpg/800px-Notorious_film_poster.jpg"),
        ("The Paradine Case", "6.5", "1947", "Gregory Peck", "https://upload.wikimedia.org/wikipedia/en/thumb/6/61/The_Paradine_Case_1947.jpg/800px-The_Paradine_Case_1947.jpg"),
        ("Rope", "8.0", "1948", "James Stewart", "https://upload.wikimedia.org/wikipedia/en/thumb/6/60/Rope_1948.jpg/800px-Rope_1948.jpg"),
        ("Under Capricorn", "6.4", "1949", "Ingrid Bergman", "https://upload.wikimedia.org/wikipedia/en/thumb/b/bc/Under_Capricorn_1949.jpg/800px-Under_Capricorn_1949.jpg"),
        ("Stage Fright", "7.1", "1950", "Jane Wyman", "https://upload.wikimedia.org/wikipedia/en/thumb/6/6f/Stage_Fright_1950.jpg/800px-Stage_Fright_1950.jpg"),
        ("Strangers on a Train", "7.9", "1951", "Farley Granger", "https://upload.wikimedia.org/wikipedia/en/thumb/7/7d/Strangers_on_a_train.jpg/800px-Strangers_on_a_train.jpg"),
        ("I Confess", "7.0", "1953", "Montgomery Clift", "https://upload.wikimedia.org/wikipedia/en/thumb/7/75/I_Confess_1953.jpg/800px-I_Confess_1953.jpg"),
        ("To Catch a Thief", "7.4", "1955", "Cary Grant, Grace Kelly", "https://upload.wikimedia.org/wikipedia/en/thumb/c/cc/To_Catch_a_Thief.jpg/800px-To_Catch_a_Thief.jpg"),
        ("The Wrong Man", "7.4", "1956", "Henry Fonda", "https://upload.wikimedia.org/wikipedia/en/thumb/0/02/The_Wrong_Man_1956.jpg/800px-The_Wrong_Man_1956.jpg"),
        ("The Man Who Knew Too Much", "7.4", "1956", "James Stewart", "https://upload.wikimedia.org/wikipedia/en/thumb/f/fe/The_Man_Who_Knew_Too_Much_%281956%29.jpg/800px-The_Man_Who_Knew_Too_Much_%281956%29.jpg"),
        ("The Wrong Man", "7.4", "1956", "Henry Fonda", "https://upload.wikimedia.org/wikipedia/en/thumb/0/02/The_Wrong_Man_1956.jpg/800px-The_Wrong_Man_1956.jpg"),
        ("Vertigo", "8.3", "1958", "James Stewart, Kim Novak", "https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/Vertigomovie_restoration.jpg/800px-Vertigomovie_restoration.jpg"),
        ("North by Northwest", "8.3", "1959", "Cary Grant, Eva Marie Saint", "https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/Northbynorthwest_poster.jpg/800px-Northbynorthwest_poster.jpg"),
    ]

    # --- 50 DİZİ (Açık Kaynak ve Klasik TV) ---
    series = [
        ("Cosmos Laundromat", "7.2", "S01E01", "Blender Foundation", "https://image.tmdb.org/t/p/w500/76M9S6S0Z959L9mHhU4P6B6iXhX.jpg"),
        ("Bonanza", "7.3", "S01E01", "Lorne Greene", "https://upload.wikimedia.org/wikipedia/commons/1/1a/Bonanza_cast.jpg"),
        ("Sherlock Holmes", "7.9", "S01E01", "Ronald Howard", "https://upload.wikimedia.org/wikipedia/commons/4/45/Sherlock_Holmes_1954_Title.png"),
        ("The Lucy Show", "7.5", "S01E01", "Lucille Ball", "https://upload.wikimedia.org/wikipedia/en/thumb/0/03/The_Lucy_Show_title_card.jpg/800px-The_Lucy_Show_title_card.jpg"),
        ("I Love Lucy", "8.4", "S01E01", "Lucille Ball, Desi Arnaz", "https://upload.wikimedia.org/wikipedia/en/thumb/9/9a/I_Love_Lucy_title_screen.jpg/800px-I_Love_Lucy_title_screen.jpg"),
        ("The Beverly Hillbillies", "7.1", "S01E01", "Buddy Ebsen", "https://upload.wikimedia.org/wikipedia/en/thumb/8/8a/The_Beverly_Hillbillies.jpg/800px-The_Beverly_Hillbillies.jpg"),
        ("The Dick Van Dyke Show", "8.3", "S01E01", "Dick Van Dyke", "https://upload.wikimedia.org/wikipedia/en/thumb/a/ac/Dick_Van_Dyke_Show_title_card.jpg/800px-Dick_Van_Dyke_Show_title_card.jpg"),
        ("The Honeymooners", "8.7", "S01E01", "Jackie Gleason", "https://upload.wikimedia.org/wikipedia/en/thumb/8/8e/Honeymooners_title_screen.jpg/800px-Honeymooners_title_screen.jpg"),
        ("Dragnet", "7.7", "S01E01", "Jack Webb", "https://upload.wikimedia.org/wikipedia/en/thumb/5/52/Dragnet_title_screen.jpg/800px-Dragnet_title_screen.jpg"),
        ("The Twilight Zone", "9.0", "S01E01", "Rod Serling", "https://upload.wikimedia.org/wikipedia/en/thumb/0/08/The_Twilight_Zone_title_card.jpg/800px-The_Twilight_Zone_title_card.jpg"),
        ("The Outer Limits", "7.8", "S01E01", "Vic Perrin", "https://upload.wikimedia.org/wikipedia/en/thumb/2/26/The_Outer_Limits_%281963-1965%29.jpg/800px-The_Outer_Limits_%281963-1965%29.jpg"),
        ("Star Trek", "8.4", "S01E01", "William Shatner", "https://upload.wikimedia.org/wikipedia/en/thumb/c/c0/Star_Trek_TOS_title_card.jpg/800px-Star_Trek_TOS_title_card.jpg"),
        ("The Prisoner", "8.5", "S01E01", "Patrick McGoohan", "https://upload.wikimedia.org/wikipedia/en/thumb/0/02/The_Prisoner.svg/800px-The_Prisoner.svg.png"),
        ("Doctor Who", "8.6", "S01E01", "William Hartnell", "https://upload.wikimedia.org/wikipedia/en/thumb/3/32/Doctor_Who_1963_logo.jpg/800px-Doctor_Who_1963_logo.jpg"),
        ("Steptoe and Son", "8.2", "S01E01", "Wilfrid Brambell", "https://upload.wikimedia.org/wikipedia/en/thumb/3/3e/Steptoe_and_Son.jpg/800px-Steptoe_and_Son.jpg"),
        ("The Avengers", "8.2", "S01E01", "Patrick Macnee", "https://upload.wikimedia.org/wikipedia/en/thumb/7/7e/The_Avengers_title_card.jpg/800px-The_Avengers_title_card.jpg"),
        ("The Saint", "7.5", "S01E01", "Roger Moore", "https://upload.wikimedia.org/wikipedia/en/thumb/6/66/The_Saint_1962.jpg/800px-The_Saint_1962.jpg"),
        ("Danger Man", "7.8", "S01E01", "Patrick McGoohan", "https://upload.wikimedia.org/wikipedia/en/thumb/d/d4/Danger_Man.jpg/800px-Danger_Man.jpg"),
        ("The Fugitive", "7.9", "S01E01", "David Janssen", "https://upload.wikimedia.org/wikipedia/en/thumb/9/90/The_Fugitive_1963.jpg/800px-The_Fugitive_1963.jpg"),
        ("The Man from U.N.C.L.E.", "7.8", "S01E01", "Robert Vaughn", "https://upload.wikimedia.org/wikipedia/en/thumb/6/6f/The_Man_from_UNCLE.jpg/800px-The_Man_from_UNCLE.jpg"),
        ("I Spy", "7.6", "S01E01", "Robert Culp", "https://upload.wikimedia.org/wikipedia/en/thumb/0/05/I_Spy_1965.jpg/800px-I_Spy_1965.jpg"),
        ("Get Smart", "8.1", "S01E01", "Don Adams", "https://upload.wikimedia.org/wikipedia/en/thumb/4/4d/Get_Smart_title_card.jpg/800px-Get_Smart_title_card.jpg"),
        ("Mission: Impossible", "7.2", "S01E01", "Steven Hill", "https://upload.wikimedia.org/wikipedia/en/thumb/9/90/Mission_Impossible_1966.jpg/800px-Mission_Impossible_1966.jpg"),
        ("The Invaders", "7.8", "S01E01", "Roy Thinnes", "https://upload.wikimedia.org/wikipedia/en/thumb/d/d6/The_Invaders.jpg/800px-The_Invaders.jpg"),
        ("Land of the Giants", "7.1", "S01E01", "Gary Conway", "https://upload.wikimedia.org/wikipedia/en/thumb/4/47/Land_of_the_Giants.jpg/800px-Land_of_the_Giants.jpg"),
        ("The Time Tunnel", "7.4", "S01E01", "James Darren", "https://upload.wikimedia.org/wikipedia/en/thumb/7/76/The_Time_Tunnel.jpg/800px-The_Time_Tunnel.jpg"),
        ("Voyage to the Bottom of the Sea", "7.1", "S01E01", "Richard Basehart", "https://upload.wikimedia.org/wikipedia/en/thumb/8/8d/Voyage_to_the_Bottom_of_the_Sea.jpg/800px-Voyage_to_the_Bottom_of_the_Sea.jpg"),
        ("Lost in Space", "7.2", "S01E01", "Guy Williams", "https://upload.wikimedia.org/wikipedia/en/thumb/4/4a/Lost_in_Space_1965.jpg/800px-Lost_in_Space_1965.jpg"),
        ("The Wild Wild West", "8.0", "S01E01", "Robert Conrad", "https://upload.wikimedia.org/wikipedia/en/thumb/1/1d/The_Wild_Wild_West.jpg/800px-The_Wild_Wild_West.jpg"),
        ("The High Chaparral", "7.4", "S01E01", "Leif Erickson", "https://upload.wikimedia.org/wikipedia/en/thumb/9/92/The_High_Chaparral.jpg/800px-The_High_Chaparral.jpg"),
        ("Gunsmoke", "8.2", "S01E01", "James Arness", "https://upload.wikimedia.org/wikipedia/en/thumb/7/71/Gunsmoke_title_card.jpg/800px-Gunsmoke_title_card.jpg"),
        ("Have Gun – Will Travel", "8.3", "S01E01", "Richard Boone", "https://upload.wikimedia.org/wikipedia/en/thumb/1/14/Have_Gun_Will_Travel.jpg/800px-Have_Gun_Will_Travel.jpg"),
        ("Maverick", "8.0", "S01E01", "James Garner", "https://upload.wikimedia.org/wikipedia/en/thumb/e/e0/Maverick_1957.jpg/800px-Maverick_1957.jpg"),
        ("Rawhide", "7.9", "S01E01", "Clint Eastwood", "https://upload.wikimedia.org/wikipedia/en/thumb/b/b1/Rawhide_title_card.jpg/800px-Rawhide_title_card.jpg"),
        ("Wagon Train", "7.3", "S01E01", "Ward Bond", "https://upload.wikimedia.org/wikipedia/en/thumb/6/64/Wagon_Train.jpg/800px-Wagon_Train.jpg"),
        ("The Rifleman", "8.1", "S01E01", "Chuck Connors", "https://upload.wikimedia.org/wikipedia/en/thumb/3/31/The_Rifleman.jpg/800px-The_Rifleman.jpg"),
        ("Wanted Dead or Alive", "7.9", "S01E01", "Steve McQueen", "https://upload.wikimedia.org/wikipedia/en/thumb/1/17/Wanted_Dead_or_Alive.jpg/800px-Wanted_Dead_or_Alive.jpg"),
        ("The Life and Legend of Wyatt Earp", "7.5", "S01E01", "Hugh O'Brian", "https://upload.wikimedia.org/wikipedia/en/thumb/f/f6/The_Life_and_Legend_of_Wyatt_Earp.jpg/800px-The_Life_and_Legend_of_Wyatt_Earp.jpg"),
        ("Cheyenne", "7.6", "S01E01", "Clint Walker", "https://upload.wikimedia.org/wikipedia/en/thumb/3/39/Cheyenne_title_card.jpg/800px-Cheyenne_title_card.jpg"),
        ("Sugarfoot", "7.3", "S01E01", "Will Hutchins", "https://upload.wikimedia.org/wikipedia/en/thumb/c/c7/Sugarfoot_title_card.jpg/800px-Sugarfoot_title_card.jpg"),
        ("Bronco", "7.4", "S01E01", "Ty Hardin", "https://upload.wikimedia.org/wikipedia/en/thumb/9/9c/Bronco_title_card.jpg/800px-Bronco_title_card.jpg"),
        ("Lawman", "7.7", "S01E01", "John Russell", "https://upload.wikimedia.org/wikipedia/en/thumb/6/60/Lawman_title_card.jpg/800px-Lawman_title_card.jpg"),
        ("The Deputy", "7.2", "S01E01", "Henry Fonda", "https://upload.wikimedia.org/wikipedia/en/thumb/0/0e/The_Deputy_title_card.jpg/800px-The_Deputy_title_card.jpg"),
        ("Tombstone Territory", "7.1", "S01E01", "Pat Conway", "https://upload.wikimedia.org/wikipedia/en/thumb/d/d6/Tombstone_Territory.jpg/800px-Tombstone_Territory.jpg"),
        ("Johnny Ringo", "7.3", "S01E01", "Don Durant", "https://upload.wikimedia.org/wikipedia/en/thumb/1/12/Johnny_Ringo.jpg/800px-Johnny_Ringo.jpg"),
        ("The Texan", "7.4", "S01E01", "Rory Calhoun", "https://upload.wikimedia.org/wikipedia/en/thumb/4/41/The_Texan_title_card.jpg/800px-The_Texan_title_card.jpg"),
        ("Black Saddle", "7.5", "S01E01", "Peter Breck", "https://upload.wikimedia.org/wikipedia/en/thumb/b/b3/Black_Saddle.jpg/800px-Black_Saddle.jpg"),
        ("Zane Grey Theatre", "7.8", "S01E01", "Dick Powell", "https://upload.wikimedia.org/wikipedia/en/thumb/6/6a/Zane_Grey_Theatre.jpg/800px-Zane_Grey_Theatre.jpg"),
        ("Trackdown", "7.6", "S01E01", "Robert Culp", "https://upload.wikimedia.org/wikipedia/en/thumb/a/a8/Trackdown.jpg/800px-Trackdown.jpg"),
        ("Tales of Wells Fargo", "7.9", "S01E01", "Dale Robertson", "https://upload.wikimedia.org/wikipedia/en/thumb/2/28/Tales_of_Wells_Fargo.jpg/800px-Tales_of_Wells_Fargo.jpg"),
        ("26 Men", "7.2", "S01E01", "Tristram Coffin", "https://upload.wikimedia.org/wikipedia/en/thumb/2/23/26_Men.jpg/800px-26_Men.jpg"),
        ("The Restless Gun", "7.5", "S01E01", "John Payne", "https://upload.wikimedia.org/wikipedia/en/thumb/3/3c/The_Restless_Gun.jpg/800px-The_Restless_Gun.jpg"),
    ]

    with open("demo_playlist.m3u", "w", encoding="utf-8") as f:
        f.write(header)
        
        # TV Kanallarını Yaz
        for i in range(1, 51):
            name, logo, url = live_channels[i % len(live_channels)]
            f.write(f'#EXTINF:-1 tvg-logo="{logo}" group-title="Canlı TV" description="Gerçek zamanlı dünya gündemi ve bilim yayınları.",{name} #{i}\n{url}\n\n')

        # Filmleri Yaz
        for i in range(1, 51):
            name, rate, year, cast, logo = movies[i % len(movies)]
            f.write(f'#EXTINF:-1 tvg-logo="{logo}" group-title="Filmler" description="Bu klasik yapım sinema tarihinin en önemli eserlerinden biridir." rating="{rate}" year="{year}" cast="{cast}",{name} - {i}\nhttps://download.blender.org/demo/movies/BigBuckBunny.mp4\n\n')

        # Dizileri Yaz
        for i in range(1, 51):
            name, rate, ep, cast, logo = series[i % len(series)]
            f.write(f'#EXTINF:-1 tvg-logo="{logo}" group-title="Diziler" description="Efsanevi serinin unutulmaz bölümleri." rating="{rate}" cast="{cast}" season="1" episode="{i}",{name} - Bölüm {i}\nhttps://download.blender.org/demo/movies/CosmosLaundromat-1.part1.res720p.mp4\n\n')

    print("✅ demo_playlist.m3u dosyası başarıyla oluşturuldu!")
    print("📊 Toplam içerik: 150 (50 Canlı TV + 50 Film + 50 Dizi)")

if __name__ == "__main__":
    generate_m3u()
