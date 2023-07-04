<script>
    import { blockVisible } from "../stores";
import Dropdown from "./Dropdown.svelte";

    let wallet = { connected: false };

    export async function ConnectWallet() {
        // UniSat Wallet
        wallet.connected = !wallet.connected;
        let winuni = window.unisat;
        if (typeof winuni !== "undefined") {
            try {
                if (wallet.connected) {
                    console.log("UniSat Wallet is installed!");
                    let accounts = await winuni.requestAccounts();
                    console.log("connect success", accounts);
                    
                } else {
                    console.log("Disconnect here");
                }
            } catch (e) {
                console.log("wallet not connected");
                
            }
        } else if (typeof winuni === "undefined") {
            console.log("UniSat Wallet is not installed :(");
            console.log("need link to unstall");
        }

        return wallet;
    }

    $: wallet.connected = wallet.connected;
</script>

{#if wallet.connected}
    
    <button class="danger" on:click={ConnectWallet}> Disconnect Wallet </button>
    <Dropdown></Dropdown>
   
{/if}

{#if !wallet.connected}
    <button class="primary" on:click={ConnectWallet}> Connect Wallet </button>
    
{/if}

<style>
    .primary {
        color: orange;
    }
    .danger {
        color: red;
    }
</style>
