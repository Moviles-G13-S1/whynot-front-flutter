# Sprint 3 rubric — implementation evidence and remaining validation

Source: user-supplied `Rubrica Sprint 3.pdf`, reviewed on October 28, 2026.
The rubric is assessment reference material. Completion must be backed by code
and demonstrations; this matrix does not assign or guarantee academic scores.

| Criterion | Rubric evidence | Current implementation / remaining work |
| --- | --- | --- |
| Explain teammates' strategies — 20 | Explain decisions for local storage, EvC, caching and concurrency, using technical vocabulary; initial explanation approximately one minute per member. | Prepare explanations of Juliana's drafts, Santiago's recommendation cache and Jerónimo's Home/Profile loads. Source code alone does not prove cross-member understanding. |
| Business question — 10 | Real analytical pipeline connected to the app/database, one shared dashboard/database; manual downloaded files are not accepted. | Jerónimo's weekly application-error BQ remains pending. The image cache is unrelated to this analytical pipeline. |
| Flutter concurrency — 20 | The column lists Future (5), Future with handler (5), Future with handler plus async/await (10), Stream (5), isolates (10), with platform strategy coverage considered. | HomeController/ProfileLoadController/LiveSection show asynchronous reads, stream handlers, independent results, cancellation and errors. Tests control completion order. No isolate was added; do not claim CPU parallelism or assume automatic full marks. See home-profile-concurrency.md. |
| Local storage — 20 | Relational local DB (10), key/value DB (5), local files (5), preferences or platform equivalents (5). | Product drafts already use SQLite. The Chrome photo adapter stores bytes in SQLite/IndexedDB. Explain ownership and scope rather than claiming all storage strategies from one implementation. |
| Eventual connectivity — 20 | Five points per protected view. A generic app-wide message alone is explicitly insufficient; navigation and offline features must work. | Home/Profile read available data, edit forms retain inputs, photo bytes can be reused locally, failed reads recover, and save confirmation is distinguished from pending state. New authentication still requires internet. Real-device airplane-mode and navigation demonstrations remain required. |
| Caching — 20 | Image-cache libraries (5); LRU/SparseArray/ArrayMap/NSCache (10), explaining structure, parameters and decisions. | New native photo cache uses CachedNetworkImage/flutter_cache_manager, configured per owner, one image and 30-day retention. Existing recommendation LRU has bounded capacity, expiry, recency and invalidation. Explain them separately. See profile-photo-cache.md. |

## Current checks versus remaining evidence

Automated tests and web compilation can support implementation claims. They do
not replace showing the app on an iPhone, persistence after restart, real Storage
downloads, CORS behavior in Chrome or a live BQ connected to the dashboard.
Keep existing/implemented/pending claims separate in the wiki and viva.
