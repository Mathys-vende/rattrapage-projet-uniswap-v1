## Ecole 2600 - Projet de rattrapage blockchain - Implémenter Uniswap V1

L'objectif de ce projet est d'implémenter les smart contracts du protocole Uniswap V1 à l'aide d'un tutoriel disponible en ligne sur le site https://jeiwan.net/.

### Introduction

Le protocole Uniswap V1 permet de déployer des smart contracts de pools de liquidité permettant:

- à des traders d'échanger (swapper) des tokens contre de l'ETH (et inversement)
- à des liquidity providers de fournir de la liquidité à la pool pour être payé en échange pour chaque swap

Uniswap V1 a été déployé fin 2018 sur le réseau Ethereum. Ce projet à permis d'augmenter fortement le volume de transactions on-chain grace à un modèle adapté aux contraintes du réseau décentralisé. Une forte croissance du secteur de la finance décentralisée à suivi, ainsi que le développement de nouveaux protocoles innovants construit en surcouche d'Uniswap.

Depuis on a vu les évolutions V2, V3 et V4 de Uniswap, rendant la V1 obsolète. Mais le protocole étant immutable, il reste déployé et ses contrats ont encore de la liquidité qui génère du rendement. Voici par exemple le contrat de la pool ETH-USDC, qui contient environ \$900,000 de liquidité au moment ou j'écris ces lignes: https://etherscan.io/address/0x97deC872013f6B5fB443861090ad931542878126

Pour comparaison, la même pool sur Uniswap V3 contient environ $300,000,000 de liquidité.

### Mise en place

Commencez par créer un fork de ce repository sur votre compte Gitlab puis clonez localement votre fork.

Remplissez ensuite le fichier google spreadsheet partagé par l'école avec votre nom, prénom, URL de repository et email sur une nouvelle ligne.

Vous aurez besoin de Foundry, le SDK solidity que j'utilise pour tester votre code: https://getfoundry.sh/

Une fois installé, placez vous à la racine du repo et lancez la commande:

```bash
forge test
```

La commande devrait se lancer mais afficher "No tests to run", c'est normal, les tests seront ajoutés par la suite.

### Implémenter le modèle UniV1 en python

L'objectif de cette partie est d'appréhender le modèle mathématique derrière les pools Uniswap V1 via une implémentation simple de la formule de swap dans un fichier de test python.

Commencez par regarder la vidéo suivante de la chaine Finematics: [How do LIQUIDITY POOLS work?](https://www.youtube.com/watch?v=cizLhxSKrAc)

Cette vidéo explique d'abord pourquoi le modèle de pools de liquidité est très adapté aux réseaux décentralisés, par opposition au modèle d'échanges par orderbook.

La vidéo détaille ensuite le modèle de pools de liquidité et les mathématiques sous-jacente: le constant product automated market making.

#### Mathématiques du constant product market making

Soit une pool permettant d'échanger des tokens X et Y, dont les reserves sont notés respectivement $x$ et $y$, alors le produit $x.y$ doit rester constant à chaque swap, ce qui est traduit par l'équation:

$$x.y=k$$

$k$ étant une constante mesurant la liquidité de la pool. Cette constante ne change que quand on ajoute ou retire de la liquidité dans la pool, mais pas lors d'un swap.

Le fait d'imposer cette condition nous permet de dériver une formule pour calculer les échanges, c'est à dire le pricing de la pool.

Soit $\Delta x$ un nombre de tokens X fourni par un trader, on souhaite calculer la quantity $\Delta y$ de tokens Y que la pool lui donne en échange.

La pool "achète" donc $\Delta x$ tokens X, et sa reserve de tokens X devient $x' = x + \Delta x$. Et elle vend $\Delta y$ tokens Y, donc sa reserve de tokens Y devient $y' = y - \Delta y$.

Le produit doit rester constant, on doit donc avoir:

$$
\begin{align*}
x'.y' &= k = x.y\\
(x + \Delta x)(y - \Delta y) &= x.y
\end{align*}
$$

On veut calculer $\Delta y$ (l'inconnue) en fonction des autres paramètres (connus), on isole donc cette variable:

$$
\begin{align*}
(x + \Delta x)(y - \Delta y) &= x.y \\
y - \Delta y &= \frac{x.y}{x + \Delta x} \\
-\Delta y &= \frac{x.y}{x + \Delta x} - y \\
\Delta y &= y - \frac{x.y}{x + \Delta x} \\
\end{align*}
$$

C'est la formule de swap qui permet de calculer le nombre $\Delta y$ de tokens Y acheté par le trader à la pool en échange de $\Delta x$ tokens X.

Afin que cela soit plus parlant, prenons un example basé sur des données réelles. A l'heure ou j'écris ces lignes, le prix d'ETH est d'environ $3,694 sur l'exchange centralisé Binance. La pool ETH-USDC UniV1 mentionnée plus haut possède les reserves suivantes:

- $x$ = 123.005071763679216071 ETH
- $y$ = 453,357.751946 USDC

Voyons ci ces reserves conduisent à un prix proche de celui de Binance. Pour cela je calcule $\Delta y$ en posant $\Delta x$ = 1 ETH:

$$
\begin{align*}
\Delta y &= y - \frac{x.y}{x + \Delta x} \\ &= 453,357.751946 -\frac{123.005071763679216071 \times 453,357.751946}{123.005071763679216071 + 1}
\end{align*}
$$

En python:

```python
In [9]: 453_357.751946-(123.005071763679216071*453_357.751946)/(123.005071763679216071+1)
Out[9]: 3655.9613691444392
```

$3,655.96 est donc le prix proposée par la pool en échange d'un ETH. On note que le prix sur Binance de \$3,694 est légèrement plus élevé.

Il serait donc possible en théorie d'arbitrer la pool pour corriger son prix, tout en faisant un profit: on peut acheter un ETH à la pool et aller le vendre sur Binance, le profit serait d'environ $40.

C'est de cette manière que les pool Uniswap gardent un prix proche de celui des autres exchanges: quand le prix s'éloigne trop, une opportunité d'arbitrage se créé et des traders en profite.

Ce qui peut expliquer que ça ne soit pas déjà arbitré ici, ce sont les couts de réseau et le price impact.

Une transaction sur Ethereum peut couter plusieurs dizaines de dollard, sans compter la nécessité d'envoyer les fonds sur le réseaux, et les extraire. Pour que l'arbitrage soit profitable, il faudrait un écart de prix assez important pour couvrir ces frais.

En plus de cela, le raisonnement présenté ci-dessus est faux: le profit théorique n'est pas de \$40, car en réalité la pool ne me vendrait pas un ETH contre \$3655.9613691444392. On a fait le calcul en supposant que c'est moi qui vent un ETH à la pool, et elle me donne \$3655.9613691444392 en échange. Mais le calcul n'est pas symmetrique, la pool ne me vend pas un ETH contre \$3655.9613691444392. Pour le constater, on peut faire le calcul en inversant $x$ et $y$, et en essayant de "vendre" $\Delta y = 3655.96$ à la pool:

$$
\begin{align*}
\Delta x &= x - \frac{x.y}{y + \Delta y} \\ &= 123.005071763679216071 -\frac{123.005071763679216071 \times 453,357.751946}{453,357.751946 + 3655.9613691444392}
\end{align*}
$$

En python:


```python
In [9]: 123.005071763679216071-(123.005071763679216071*453_357.751946)/(453_357.751946+3655.9613691444392)
Out[9]: 0.9840006491593982
```

Je n'obtient donc que 0.9840002836025974 ETH en échange de 3655.96 USDC. Quelle deception. L'arbitrage n'est donc pas reellement possible ici, en tout cas pas pour une valeur de 1 ETH, qui est trop élevé par rapport à la liquidité fournie par la pool. L'arbitrage serait peut être possible pour 0.1 ETH, ou moins, il faudrait faire le calcul. Mais plus on réduit ce nombre, moins le potentiel de gain est elevé, et plus les frais de réseaux empèchent l'arbitrage.

Cette différence entre prix d'achat et prix de vente, c'est le price impact: mon propre impact sur les liquidité de la pool, et donc sur le nouveau prix qu'elle propose.

#### Prix "spot" d'une pool et price impact

Le prix spot d'une pool représente son prix actuel théorique. On peut le calculer via $\frac{x}{y}$ pour obtenir le prix de $Y$ exprimé en $X$, et inversement via $\frac{y}{x}$ pour obtenir le prix de $X$ exprimé en $Y$.

Reprenons l'example:

- $x$ = 123.005071763679216071 ETH
- $y$ = 453,357.751946 USDC

On a $\frac{y}{x}=\frac{453,357.751946}{123.005071763679216071} = 3685.683406754183$. On obtient bien un nombre très proche du prix d'ETH mentionné plus haut. Pourtant ce nombre diffère de celui calculé lors d'un swap: $3655.9613691444392$.

Cette différence s'appelle le price impact, et augmente lorsque l'on tente de swapper des montant plus élevé. C'est logique, la formule de pricing $x.y=k$ est utilisée pour permettre de proposer des prix dans la range $(0, +\infty)$ quelque soit les reserves de la pool. Ainsi, plus on tente de "vider" la pool d'un de ses assets, plus elle augmente son prix pour compenser. Le prix spot de la pool est donc $3685.683406754183$ USDC par ETH, mais je n'obtiendrais ce prix que pour de petits montants. Pour 1 ETH complet, la pool ne me donne que $3655.9613691444392$ USDC.

Une manière de réduire le price impact est d'apporter plus de liquidité à la pool (augmente les reserves $x$ et $y$). Pour un même prix, plus $x$ et $y$ sont élevé et plus le price impact est faible. On dit que la pool à une forte profondeur de liquidité lorsqu'elle est capable de gérer de gros swaps.

> Pour information, le modèle constant product est très pratique pour gérer une range de prix infini et une gestion passive, mais à l'inconvénient d'être très peu capital efficient: il faut une grande quantitée de liquidité pour gérer de gros swaps sans price impact.
> Uniswap V3 implémente un modèle plus avancé appelé "concentrated liquidity", permettant de concentrer la liquidité dans des ranges de prix. Ce modèle perd l'avantage de la passivité (les liquidity providers doivent devenir actifs: choisir leur range de prix), mais à la capacité de gérer de plus gros volumes avec moins de liquidité, et donc de gagner plus d'argent sur les frais de trading.

#### Gestions des frais de trading

Les liquidity providers ne fournissent pas leur liquidité gratuitement, ils cherchent à obtenir un rendement en prenant des frais à chaque swap.

Les frais appliqués par Uniswap V1 sont de 0.3% à chaque swap, payé dans le token apporté par le trader (si j'échange ETH contre USDC je paye mes frais en ETH, si USDC contre ETH je les paye en USDC). Le tutoriel en solidity à implémenter dans la partie suivante utilise des frais de 1%.

De manière générale, si $p_f$ représente le pourcentage de fees, alors on multiplie $\Delta x$ par $\frac{(100 - p_f)}{100}$ avant d'appliquer la formule de swap afin de retrancher les frais. Afin de simplifier les chose on peut poser $f = \frac{(100 - p_f)}{100}$ et la formule de swap devient:

$$\Delta y = y - \frac{x.y}{x + f.\Delta x}$$

Les reserves de la pool deviennent:

$$
\begin{align}
x &\leftarrow x+\Delta x \\
y &\leftarrow y-\Delta y
\end{align}$$

Les frais sont uniquement appliqué sur la formule de swap, le trader récupère donc un $\Delta y$ légèrement plus faible que si aucun frais n'était pris. La pool par contre a ses reserves de X augmenté de la totalité de $\Delta x$.

On peut donc en conclure qu'après le swap, la constante de sera plus respectée, on aura $x.y > k$ après le swap. Cela n'invalide pas le modèle pour autant car l'equation ne sert qu'au pricing. On peut interpreter ça comme une augmentation de la liquidité grace aux frais prélevés. Si on essaye de simuler une séquence de swaps +1 ETH, -1 ETH, +1 ETH, ..., on constatera que k augmente au fur à mesure des swaps et que le price impact se réduit.

#### Implémentation en python

Assez de théorie, passons à l'implémentation. Votre objectif est de compléter le fichier `test/pool.py` de manière à passer tous les tests du fichier `test/test_pool.py`

Commencez par créer un environnement virtuel python, installer les dépendances, et tester que `pytest` fonctionne:

```bash
python -m venv .venv
source .venv/bin/activate # Sous windows avec Git bash: source .venv/Scripts/activate
python -m pip install -r requirements.txt
python -m pytest
```

Les tests doivent échouer dans un premier temps, puis passer suite à votre implémentation.

On modélise une pool avec une classe `Pool` stockant les reserves, le pourcentage de frais, et proposant des méthodes pour swapper d'un asset à l'autre. Ces méthodes sont à implémenter en utilisant les formules ci-dessus.

Bien lire les fonction de test du fichier `test/test_pool.py` pour comprendre le comportement attendu. Les examples de nombre utilisés sont ceux utilisé plus haut dans l'explication mathématique.

Après implémentation, bien re-vérifier que tous les tests passent, faire un commit et un push:

```bash
python -m pytest # Doit passer !
git add test/pool.py
git commit -m "Implement python part"
```

### Impémentation en solidity

L'objectif de cette partie est l'implémentation en Solidity du protocole. Pour cela vous suivrez les 3 parties du tutorial suivant:

- https://jeiwan.net/posts/programming-defi-uniswap-1/
- https://jeiwan.net/posts/programming-defi-uniswap-2/
- https://jeiwan.net/posts/programming-defi-uniswap-3/

Ce tutorial a été écrit en utilisant le SDK Hardhat, mais j'ai réécris les tests pour le SDK Foundry. Vous pouvez donc ignorer tout ce qui touche à hardhat (mise en place du projet avec `yarn`, installation de dépendences, tests écris en javascript, ...).

Votre unique job est d'implémenter les contrats `src/Token.sol`, `src/Exchange.sol` et `src/Factory.sol` en suivant le tutoriel.

J'ai configuré le repo Git pour avoir des tags mergeable contenant les tests de chaque partie.

Le flow de développement à suivre est le suivant:

```bash
# Recup les tests de la partie 1
git merge origin/part-1 -m "Merge tests part 1"

# Implémenter la partie 1, tester et débugguer avec:
forge test -vvv

# Une fois que la partie 1 passe les tests, commiter les sources:
git add src/*.sol
git commit -m "Implement part 1"

# Recup les tests de la partie 2
git merge origin/part-2 -m "Merge tests part 2"

# Implémenter la partie 2, tester et débugguer avec:
forge test -vvv

# Une fois que la partie 2 passe les tests, commiter les sources:
git add src/*.sol
git commit -m "Implement part 2"

# Recup les tests de la partie 3
git merge origin/part-3 -m "Merge tests part 3"

# Implémenter la partie 3, tester et débugguer avec:
forge test -vvv

# Une fois que la partie 3 passe les tests, commiter les sources:
git add src/*.sol
git commit -m "Implement part 3"
```

C'est ce dernier commit que je noterais (code solidity et code python). Les tests solidity en eux même ne doivent pas avoir été modifié (je replacerais mes propres fichiers).

Attention si vous modifiez les fichiers de test au cours du développement (pour ajouter des `console.log` et débugguer par exemple), vous aurez les merge conflict lors des appels à `git merge`. Pensez donc à revert les changements git sur ces fichiers avant de tenter le merge.

La commande pour lancer les tests est:

```bash
forge test
```

Lorsqu'un test ne passe pas et que vous voulez le débugguer, ajouter des `-v` derrière la commande, et cibler un test en particulier avec `--match-test`, example:

```bash
forge test --match-test test_ItMintsLPTokens -vvv
```

Le `-v` correspond à "verbose", et plus vous ajoutez de `v` plus vous obtiendrez de détail sur l'origine de l'échec du test.

Il est important d'aller lire les tests et les comprendre, surtout lorsque ça échoue. Referrez vous à la doc pour comprendre les appels à la lib standard de foundry: https://book.getfoundry.sh/cheatcodes/

L'implémentation en solidity amène une certaine complexité par rapport au python. Par exemple, solidity ne supporte pas les nombres flottant, il faut donc tout faire avec des entiers. En plus de cela vous implémenterez l'ajout et le retrait de liquidité, ainsi que la collecte de frais à travers la notion de LP-tokens.

Le tutoriel est  bien écrit et guide suffisement pour arriver facilement au bout.

## Foundry

> Ci dessous le README original d'un projet vide foundry, peut vous servir de reference pour certaines commande

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
