pragma Singleton

import QtQuick
import qs.utils

QtObject {
    id: root

    function normalizeText(v: var): string {
        return (v ?? "").toString().toLowerCase().trim();
    }

    // Vector Search (Sparse N-Grams)
    function getNGrams(str: string, n: int): var {
        let ngrams = {};
        if (!str) return ngrams;
        const s = str.toLowerCase().replace(/[^a-z0-9]/g, '');
        for (let i = 0; i <= s.length - n; i++) {
            const gram = s.substring(i, i + n);
            ngrams[gram] = (ngrams[gram] || 0) + 1;
        }
        if (s.length > 0 && s.length < n) {
            ngrams[s] = 1;
        }
        return ngrams;
    }

    function vectorDotProduct(queryVector: var, targetVector: var): real {
        let score = 0;
        for (let gram in queryVector) {
            if (targetVector[gram]) {
                score += queryVector[gram] * targetVector[gram];
            }
        }
        return score;
    }

    property var searchIndex: []

    function extractKeywords(pagePath: string): var {
        if (!pagePath) return {};
        let url = Qt.resolvedUrl("pages/" + pagePath);
        let xhr = new XMLHttpRequest();
        xhr.open("GET", url, false);
        try {
            xhr.send(null);
        } catch (e) {
            return {};
        }
        let content = xhr.responseText;
        if (!content) return {};
        
        let regex = /(?:text|label|title):\s*qsTr\(['"]([^'"]+)['"]\)/g;
        let match;
        let ngrams = {};
        while ((match = regex.exec(content)) !== null) {
            let kwGrams = getNGrams(match[1], 3);
            for (let k in kwGrams) {
                ngrams[k] = (ngrams[k] || 0) + kwGrams[k];
            }
        }
        return ngrams;
    }

    function buildIndex() {
        let index = [];
        const pages = PageDictionary.pages;
        
        pages.forEach((page, pageIdx) => {
            // Add the parent page itself to the index
            let parentEntry = {
                settingLabel: page.label,
                settingDescription: page.description || "",
                pageIdx: pageIdx,
                subPageIdx: -1,
                pageLabel: qsTr("Main Page"),
                pageIcon: page.icon,
                
                labelVector: getNGrams(page.label, 3),
                descVector: getNGrams(page.description || "", 3),
                pageVector: getNGrams(page.category, 3),
                keywordVector: getNGrams(page.label, 3) // Page name as keyword
            };
            index.push(parentEntry);

            if (!page.settings) return;
            page.settings.forEach((setting) => {
                let entry = {
                    settingLabel: setting.label,
                    settingDescription: setting.description || "",
                    pageIdx: pageIdx,
                    subPageIdx: setting.subPageIdx !== undefined ? setting.subPageIdx : -1,
                    pageLabel: page.label,
                    pageIcon: page.icon,
                    
                    labelVector: getNGrams(setting.label, 3),
                    descVector: getNGrams(setting.description || "", 3),
                    pageVector: getNGrams(page.label + " " + page.category, 3),
                    keywordVector: getNGrams(page.label, 3) // Implicitly add page name to keywords
                };
                
                if (setting.keywords) {
                    setting.keywords.forEach(kw => {
                        let kwGrams = getNGrams(kw, 3);
                        for (let k in kwGrams) {
                            entry.keywordVector[k] = (entry.keywordVector[k] || 0) + kwGrams[k];
                        }
                    });
                }
                
                if (setting.pagePath) {
                    let extracted = extractKeywords(setting.pagePath);
                    for (let k in extracted) {
                        entry.keywordVector[k] = (entry.keywordVector[k] || 0) + extracted[k];
                    }
                }
                
                index.push(entry);
            });
        });
        searchIndex = index;
    }

    Component.onCompleted: {
        buildIndex();
    }

    function fuzzyPages(query: string): list<var> {
        const needle = normalizeText(query);
        const indexed = pages.map((page, pageIdx) => ({
            page,
            pageIdx
        }));

        if (!needle)
            return indexed;
            
        let queryVector = getNGrams(needle, 3);
        let qMag = 0;
        for (let gram in queryVector) {
            qMag += queryVector[gram];
        }
        if (qMag === 0) return indexed;

        return indexed.map(e => {
            let labelV = getNGrams(e.page.label, 3);
            let descV = getNGrams(e.page.description || "", 3);
            let catV = getNGrams(e.page.category, 3);
            
            const labelScore = vectorDotProduct(queryVector, labelV) / qMag;
            const descScore = vectorDotProduct(queryVector, descV) / qMag;
            const categoryScore = vectorDotProduct(queryVector, catV) / qMag;
            
            let exactBonus = 0;
            if (e.page.label.toLowerCase().startsWith(needle)) exactBonus += 5;
            
            const score = Math.max(labelScore * 2, descScore * 0.7, categoryScore * 0.4) + exactBonus;
            return {
                page: e.page,
                pageIdx: e.pageIdx,
                score
            };
        }).filter(e => e.score >= 0.5).sort((a, b) => b.score - a.score || a.pageIdx - b.pageIdx);
    }

    function fuzzyEntries(query: string): list<var> {
        if (!query || query.trim() === "") return [];
        
        let q = query.trim().toLowerCase();
        let queryVector = getNGrams(q, 3);
        
        let qMag = 0;
        for (let gram in queryVector) {
            qMag += queryVector[gram];
        }
        if (qMag === 0) return [];
        
        let results = [];
        
        for (let i = 0; i < searchIndex.length; i++) {
            let entry = searchIndex[i];
            
            let exactBonus = 0;
            if (entry.settingLabel.toLowerCase().startsWith(q)) exactBonus += 5;
            
            let lScore = vectorDotProduct(queryVector, entry.labelVector) * 3;
            let dScore = vectorDotProduct(queryVector, entry.descVector) * 1;
            let kScore = vectorDotProduct(queryVector, entry.keywordVector) * 2;
            let pScore = vectorDotProduct(queryVector, entry.pageVector) * 0.5;
            
            let totalScore = (lScore + dScore + kScore + pScore) / qMag + exactBonus;
            
            if (totalScore >= 1.2) { 
                let res = Object.assign({}, entry);
                res.score = totalScore;
                results.push(res);
            }
        }
        
        return results.sort((a, b) => b.score - a.score);
    }

    readonly property list<var> pages: PageDictionary.pages

    function indexForKey(key: string): int {
        for (let i = 0; i < pages.length; i++) {
            if (pages[i].key === key) return i;
        }
        return -1;
    }
}
