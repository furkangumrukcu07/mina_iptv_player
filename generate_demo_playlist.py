def _placeholder_logo(text: str) -> str:
    safe = text.replace(" ", "+")
    return f"https://dummyimage.com/512x512/0f172a/ffffff.png&text={safe}"


def _placeholder_poster(text: str) -> str:
    safe = text.replace(" ", "+")
    return f"https://dummyimage.com/600x900/111827/ffffff.png&text={safe}"


def generate_m3u(output_path: str = "demo_playlist_5x10x3.m3u") -> None:
    header = '#EXTM3U x-tvg-url="https://worker-9dd4.onrender.com/guide.xml"\n\n'

    sample_streams = [
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
    ]

    live_categories = [
        "Live News",
        "Live Sports",
        "Live Music",
        "Live Documentary",
        "Live Kids",
    ]
    movie_categories = [
        "Movie Action",
        "Movie Comedy",
        "Movie Sci-Fi",
        "Movie Drama",
        "Movie Family",
    ]
    series_categories = [
        "Series Crime",
        "Series Comedy",
        "Series Sci-Fi",
        "Series Drama",
        "Series Adventure",
    ]

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(header)

        # 5 kategori x 10 canlı kanal
        for category in live_categories:
            for idx in range(1, 11):
                name = f"Mina {category} Channel {idx}"
                logo = _placeholder_logo(name)
                stream_url = sample_streams[(idx - 1) % len(sample_streams)]
                f.write(
                    f'#EXTINF:-1 tvg-id="live.{category.lower().replace(" ", ".")}.{idx:02d}" '
                    f'tvg-name="{name}" tvg-logo="{logo}" group-title="{category}",{name}\n'
                )
                f.write(f"{stream_url}\n\n")

        # 5 kategori x 10 film (logo + poster alanı)
        for category in movie_categories:
            for idx in range(1, 11):
                name = f"Mina {category} Film {idx}"
                logo = _placeholder_logo(name)
                poster = _placeholder_poster(f"{category} {idx}")
                stream_url = sample_streams[(idx - 1) % len(sample_streams)]
                f.write(
                    f'#EXTINF:-1 tvg-id="movie.{category.lower().replace(" ", ".")}.{idx:02d}" '
                    f'tvg-name="{name}" tvg-logo="{poster}" logo="{logo}" poster="{poster}" '
                    f'group-title="{category}" type="movie",{name}\n'
                )
                f.write(f"{stream_url}\n\n")

        # 5 kategori x 10 dizi bölümü (logo + poster alanı)
        for category in series_categories:
            for idx in range(1, 11):
                name = f"Mina {category} S01E{idx:02d}"
                logo = _placeholder_logo(name)
                poster = _placeholder_poster(f"{category} S01E{idx:02d}")
                stream_url = sample_streams[(idx - 1) % len(sample_streams)]
                f.write(
                    f'#EXTINF:-1 tvg-id="series.{category.lower().replace(" ", ".")}.{idx:02d}" '
                    f'tvg-name="{name}" tvg-logo="{poster}" logo="{logo}" poster="{poster}" '
                    f'group-title="{category}" type="series" season="1" episode="{idx}",{name}\n'
                )
                f.write(f"{stream_url}\n\n")

    print(f"OK: {output_path} olusturuldu.")
    print("Icerik: 50 Canli + 50 Film + 50 Dizi = 150")
    print("Kategori dagilimi: her turde 5 kategori, kategori basi 10 icerik")
    print("Gorseller: telifsiz placeholder logo/poster URL")


if __name__ == "__main__":
    generate_m3u()
