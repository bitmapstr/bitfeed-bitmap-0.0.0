<script>
    import { blockVisible } from "../stores";
    import Dropdown from "./Dropdown.svelte";

    let wallet = { connected: false };

    function toggle() {
        wallet.connected = !wallet.connected;
    }

    export async function ConnectWallet() {
        // UniSat Wallet
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
    $: accounts = accounts
</script>
<slot>

{#if wallet.connected}
    <button class="danger" on:click={toggle}> Disconnect Wallet </button>
    <!-- <p>connected with {accounts}</p> -->
    <Dropdown />

   
{/if}
{#if !wallet.connected}
    <button class="primary" on:click={toggle}> Connect Wallet </button>
    <br>
    <button>UniSat</button>
    <br>
    <button>Hiro</button>
    <br>
    <button>Xverse</button>
{/if}
</slot>

<style>
    .primary {
        color: orange;
    }
    .danger {
        color: red;
    }
</style>
