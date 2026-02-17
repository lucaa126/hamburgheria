import { Component, OnInit, OnDestroy, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, RouterModule } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { FormsModule } from '@angular/forms';

interface Product {
  id: number;
  nome: string;
  prezzo: number;
  categoria: string;
  immagine?: string;
}

interface Order {
  id: number;
  stato: string;
  data_creazione: string;
}

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, CommonModule, RouterModule, FormsModule],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App implements OnInit, OnDestroy {
  private http = inject(HttpClient);
  
  // ⚠️ ASSICURATI DI INSERIRE IL TUO LINK CODESPACES CORRETTO (senza lo slash finale)
  private apiUrl = 'https://silver-space-potato-r47pj5vpv74jh5r47-5000.app.github.dev';

  // --- STATO CON SIGNALS ---
  isMobileMenuOpen = signal(false);
  activeTab = signal<'ordini' | 'menu'>('ordini');
  activeCategory = signal('Tutte');
  
  orders = signal<Order[]>([]);
  menuItems = signal<Product[]>([]);
  showAddModal = signal(false);

  categories = ['Tutte', 'Panini', 'Fritti', 'Bevande', 'Menu'];
  
  // Aggiunto campo immagine vuoto di default
  newProduct = { nome: '', prezzo: 0, categoria: 'Panini', immagine: '' };
  
  private pollingInterval: any;

  ngOnInit() {
    this.loadOrders();
    this.loadProducts();

    // AUTO-REFRESH: Controlla nuovi ordini ogni 5 secondi
    this.pollingInterval = setInterval(() => {
      this.loadOrders();
    }, 5000);
  }

  ngOnDestroy() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }
  }

  // --- LOGICA INTERFACCIA ---
  toggleMenu() { this.isMobileMenuOpen.update(val => !val); }
  closeMenu() { this.isMobileMenuOpen.set(false); }
  
  openAddProductModal() { this.showAddModal.set(true); }
  
  closeModal() { 
    this.showAddModal.set(false); 
    this.newProduct = { nome: '', prezzo: 0, categoria: 'Panini', immagine: '' };
  }

  // Lettura del file immagine e conversione in Base64
  onFileSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e: any) => {
        this.newProduct.immagine = e.target.result;
      };
      reader.readAsDataURL(file);
    }
  }

  // --- CHIAMATE AL BACKEND ---
  loadProducts() {
    this.http.get<Product[]>(`${this.apiUrl}/products`).subscribe({
      next: (data) => this.menuItems.set(data),
      error: (err) => console.error('Errore prodotti:', err)
    });
  }

  loadOrders() {
    this.http.get<Order[]>(`${this.apiUrl}/orders`).subscribe({
      next: (data) => this.orders.set(data),
      error: (err) => console.error('Errore ordini:', err)
    });
  }

  changeOrderStatus(orderId: number, nuovoStato: string) {
    this.http.put(`${this.apiUrl}/orders/${orderId}`, { stato: nuovoStato }).subscribe({
      next: () => {
        this.loadOrders();
      },
      error: (err) => console.error('Errore stato:', err)
    });
  }

  deleteMenuItem(id: number) {
    if(confirm('Sei sicuro di voler eliminare questo prodotto?')) {
      this.http.delete(`${this.apiUrl}/products/${id}`).subscribe({
        next: () => {
          this.loadProducts();
        },
        error: (err) => console.error('Errore eliminazione:', err)
      });
    }
  }

  saveProduct() {
    this.http.post(`${this.apiUrl}/products`, this.newProduct).subscribe({
      next: () => {
        this.loadProducts();
        this.closeModal();
      },
      error: (err) => console.error('Errore salvataggio:', err)
    });
  }
}