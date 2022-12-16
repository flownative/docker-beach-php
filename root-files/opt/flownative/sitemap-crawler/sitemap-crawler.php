#!/opt/flownative/php/bin/php
<?php

/*
 * Sitemap Crawler
 *
 * (c) Robert Lemke, Flownative GmbH - www.flownative.com
 */

if (PHP_MAJOR_VERSION >= 9) {
    echo "This script is not compatible with PHP 9 or higher yet\n";
    exit (1);
}

if (getenv('FLOWNATIVE_LOG_PATH') === false) {
    echo "Missing environment variable FLOWNATIVE_LOG_PATH\n";
    exit (1);
}

$internalBaseUrl = getenv('SITEMAP_CRAWLER_INTERNAL_BASE_URL');
if (empty($internalBaseUrl)) {
    $internalBaseUrl = 'http://localhost:8080';
}

$sitemapUrl = getenv('SITEMAP_CRAWLER_SITEMAP_URL');
if (empty($sitemapUrl)) {
    $sitemapUrl = 'http://localhost:8080/sitemap.xml';
}
$sitemapUrls = explode(',', $sitemapUrl);

foreach ($sitemapUrls as $sitemapUrl) {
    $crawler = new SitemapCrawler($sitemapUrl, $internalBaseUrl);
    $crawler->crawl();
}

final class SitemapCrawler
{
    protected string $sitemapUrl;
    protected string $internalBaseUrl;
    protected array $urls = [];
    protected string $logPathAndFilename;

    /**
     * @param string $sitemapUrl
     * @param string $internalBaseUrl
     */
    public function __construct(string $sitemapUrl, string $internalBaseUrl)
    {
        $this->logPathAndFilename = getenv('FLOWNATIVE_LOG_PATH') . '/sitemap-crawler.log';
        try {
            $this->sitemapUrl = $sitemapUrl;
            $this->internalBaseUrl = trim($internalBaseUrl, ' /');
            $this->parseSitemap($sitemapUrl);
        } catch (\Throwable $throwable) {
            $this->log($throwable->getMessage());
            exit (1);
        }
    }

    /**
     * @return void
     */
    public function crawl(): void
    {
        $firstUrl = reset($this->urls);
        $parsedFirstUrl = parse_url($firstUrl);
        $internalFirstUrl = $this->internalBaseUrl . $parsedFirstUrl['path'] . (isset($parsedFirstUrl['query']) ? '?' . $parsedFirstUrl['query'] : '');

        $this->log(sprintf('Checking connectivity by retrieving %s, simulating host %s', $internalFirstUrl, $parsedFirstUrl['host']));

        $retries = 0;
        $connectivityTestSucceeded = false;
        while ($retries < 10) {
            $retries++;
            sleep (2^$retries);

            $curlHandle = curl_init($internalFirstUrl);
            $headers = ['Host: ' . $parsedFirstUrl['host'], 'X-Forwarded-Proto: ' . ($parsedUrl['scheme'] ?? 'https')];
            curl_setopt($curlHandle, CURLOPT_HTTPHEADER, $headers);
            curl_setopt($curlHandle, CURLOPT_USERAGENT, 'Mozilla/5.0 (compatible; FlownativeSitemapCrawler; +https://www.flownative.com)');
            /** @noinspection CurlSslServerSpoofingInspection */
            curl_setopt($curlHandle, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($curlHandle, CURLOPT_RETURNTRANSFER, true);
            $status = curl_exec($curlHandle);
            if ($status === false) {
                $this->log(sprintf('Request failed'));
                continue;
            }

            $responseCode = curl_getinfo( $curlHandle,CURLINFO_RESPONSE_CODE);
            if ($responseCode === 200) {
                $connectivityTestSucceeded = true;
                $this->log(sprintf('Request succeeded'));
                break;
            }

            $this->log(sprintf('Returned response code %s', $responseCode));
        }

        if (!$connectivityTestSucceeded) {
            $this->log('Connectivity check retries exhausted, exiting');
            exit(1);
        }

        $this->log(sprintf('Crawling %s URLs contained in sitemap, accessing them internally via %s', count($this->urls), $this->internalBaseUrl));
        try {
            $chunks = array_chunk($this->urls, 5);
            foreach ($chunks as $chunk) {
                $multiHandle = curl_multi_init();
                $curlHandles = [];
                foreach ($chunk as $i => $url) {
                    $parsedUrl = parse_url($url);
                    $url = $this->internalBaseUrl . $parsedUrl['path'] . (isset($parsedUrl['query']) ? '?' . $parsedUrl['query'] : '');

                    $curlHandles[$i] = curl_init($url);
                    $headers = ['Host: ' . $parsedUrl['host'], 'X-Forwarded-Proto: ' . ($parsedUrl['scheme'] ?? 'https')];
                    curl_setopt($curlHandles[$i], CURLOPT_HTTPHEADER, $headers);
                    curl_setopt($curlHandles[$i], CURLOPT_USERAGENT, 'Mozilla/5.0 (compatible; FlownativeSitemapCrawler; +https://www.flownative.com)');
                    curl_setopt($curlHandles[$i], CURLOPT_SSL_VERIFYPEER, false);
                    curl_setopt($curlHandles[$i], CURLOPT_RETURNTRANSFER, true);
                    curl_multi_add_handle($multiHandle, $curlHandles[$i]);
                }

                $stillRunning = null;
                do {
                    $status = curl_multi_exec($multiHandle, $stillRunning);
                } while (CURLM_CALL_MULTI_PERFORM == $status);

                while ($stillRunning && $status === CURLM_OK) {
                    if (curl_multi_select($multiHandle) != -1) {
                        do {
                            $status = curl_multi_exec($multiHandle, $stillRunning);
                        } while ($status === CURLM_CALL_MULTI_PERFORM);
                    }
                }

                foreach ($curlHandles as $curlHandle) {
                    $curlInfo = curl_getinfo($curlHandle);
                    $this->log(sprintf('(%s) %s', $curlInfo['http_code'], $curlInfo['url']));
                }
            }
        } catch (\Throwable $throwable) {
            $this->log($throwable->getMessage());
            exit (1);
        }
    }

    /**
     * @param string $sitemapUrl
     * @throws Exception
     */
    private function parseSitemap(string $sitemapUrl): void
    {
        $streamContext = stream_context_create(
            [
                'ssl' => [
                    'verify_peer' => false,
                    'verify_peer_name' => false
                ]
            ]
        );

        $this->log("Loading sitemap from $sitemapUrl ...");

        $rawSitemapXml = file_get_contents($sitemapUrl, false, $streamContext);
        if ($rawSitemapXml === false) {
            return;
        }
        $sitemapXml = new SimpleXMLElement($rawSitemapXml, LIBXML_NOBLANKS);
        if ($sitemapXml->getName() === 'urlset') {
            foreach ($sitemapXml->url as $urlXml) {
                $url = (string)$urlXml->loc;
                if (!in_array($url, $this->urls, true)) {
                    $this->urls[] = $url;
                }
            }
        }
    }

    /**
     * @param $message
     */
    private function log($message): void
    {
        echo $message . chr(10);
        file_put_contents($this->logPathAndFilename, $message . chr(10), FILE_APPEND);
    }
}
