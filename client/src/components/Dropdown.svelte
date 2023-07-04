<script>
    import { searchBlockHeight } from "../utils/search";
	import wallet from "./ConnectWallet.svelte";

	export async function getMyBitmaps() {
		let insArray = [];
		try {
			const res = await window.unisat.getInscriptions(0, 50);
			console.log("Total Ins: " + res.total);
			for (let i = 0; i < res.total; i++) {
				const insID = res.list[i].inscriptionId;
				const hiro =
					"https://api.hiro.so/ordinals/v1/inscriptions/" + insID;
				const content = await fetch(hiro + "/content");
				const ins = await content.text()
				const inscriptionParts = ins.split(".")
				const bitmapNum = inscriptionParts[0]
				const bitmapText = "bitmap"
				if(ins.includes(bitmapText)) {
				insArray.push(bitmapNum)
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
		let blockheight = ''
		alert("submit alert");
	}

	let selected;
	let bitmapNum = "";
	
</script>

<h2>My bitmaps</h2>
<!-- <button id="getMyBitmaps" on:click={getMyBitmaps} > Get Bitmaps </button> -->

<form on:submit|preventDefault={handleSubmit}>

	<select bind:value={selected} on:change={() => (selected)}>
		
			{#await getMyBitmaps()}
			<p>...waiting for my bitmaps</p> 
			{:then data}
			{console.log("BITMAPS: " + data)}
			{#each data[0] as bitmap}
				<option value={bitmap}>{bitmap}</option>
			{/each}
			{/await}
		
	</select>
	
	<input bind:value={selected}  />
	<button disabled={!selected} type="submit"> Submit </button>
</form>

<p>selected bitmap {selected ? selected : "[waiting...]"}</p>

<style>
	input {
		display: block;
		width: 200px;
		max-width: 100%;
	}
</style>
