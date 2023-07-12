<script>
    let wallet = { connected: false };
    wallet.connected = !wallet.connected;
    async function ConnectWallet() {
		let winuni = window.unisat;

		if (typeof winuni !== 'undefined') {
			console.log('UniSat Wallet is installed!');
		} else {
			console.log('UniSat Wallet is not installed :(');
		}

		try {
			let accounts = await winuni.requestAccounts();
			console.log('connect success', accounts);
		} catch (e) {
			console.log('connect failed');
		}
		
	}

    async function GetMyBitmaps() {
        let insArray = [];
        try {
            const res = await window.unisat.getInscriptions(0, 50);
            console.log("Total Ins: " + res.total);
            for (let i = 0; i < res.total; i++) {
                const insID = res.list[i].inscriptionId;
                const hiro =
                    "https://api.hiro.so/ordinals/v1/inscriptions/" + insID;
                const content = await fetch(hiro + "/content");
                const ins = await content.text();
                const inscriptionParts = ins.split(".");
                const bitmapNum = inscriptionParts[0];
                const bitmapText = "bitmap";
                if (ins.includes(bitmapText)) {
                    insArray.push(bitmapNum);
                }
                // console.log("Content: " + ins)
                // console.log("InsID: " + insID)
            }
        } catch (e) {
            console.log(e);
        }

        return [insArray];
    }

    function handleSubmit() {
        console.log("handleSubmit")
    }
   $: wallet.connected = !wallet.connected;
    $: accounts = accounts;
    let selected;
</script>

{#if wallet.connected}
<button class="danger" on:click={GetMyBitmaps}>Disconnect Wallet</button> 
{:else if !wallet.connected}
<button class="primary" on:click={ConnectWallet}>Connect a Wallet</button>
<br />
<button>UniSat</button>
<br />
<button>Hiro</button>
<br />
<button>Xverse</button>

{:else}
	<p>something else happened here</p>
{/if}

<h2>My bitmaps</h2>
<form on:submit|preventDefault={handleSubmit}>
    <select bind:value={selected} on:change={() => selected}>
        {#await GetMyBitmaps()}
            <p>...waiting for my bitmaps</p>
        {:then bitmaps}
            {console.log("BITMAPS: " + bitmaps)}
            {#each bitmaps[0] as bitmap, index}
                <option value={bitmap}>{bitmap}</option>
            {/each}
        {/await}
    </select>
    <input bind:value={selected}  />
	<button disabled={!selected} type="submit"> Submit </button>
    <p>selected bitmap {selected ? selected : "[waiting...]"}</p>   
</form>

<style>
    .primary {
        color: orange;
    }
    .danger {
        color: rgba(255, 119, 0, 0.675);
    }
    input {
        display: block;
        width: 200px;
        max-width: 100%;
    }
</style>
